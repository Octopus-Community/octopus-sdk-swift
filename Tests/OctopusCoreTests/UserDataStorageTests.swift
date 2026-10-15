//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
@testable import OctopusCore

class UserDataStorageTests: XCTestCase {
    private var injector: Injector!
    private var securedStorage: SecuredStorage!
    /// Stands for the device being unlocked or the app coming back.
    private var sessionReadTrigger: PassthroughSubject<Void, Never>!

    override func setUp() {
        injector = Injector()
        injector.registerMocks(.securedStorage)
        securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage)
        sessionReadTrigger = PassthroughSubject()
    }

    /// Apps that integrated the email link login kept the pending request — the user's email among it —
    /// in the Keychain. Nothing reads it anymore, so it must not outlive the update.
    func testLegacyMagicLinkEntriesAreWipedAtInit() throws {
        try securedStorage.set("magicLinkId", key: "magicLink_id")
        try securedStorage.set("user@example.com", key: "magicLink_email")

        _ = makeUserDataStorage()

        XCTAssertNil(securedStorage["magicLink_id"])
        XCTAssertNil(securedStorage["magicLink_email"])
    }

    func testSessionIsKeptWhileLegacyEntriesAreWiped() throws {
        try securedStorage.set("userId", key: "user_id")
        try securedStorage.set("jwt", key: "user_jwtToken")
        try securedStorage.set("clientUserId", key: "client_user_id")
        try securedStorage.set("user@example.com", key: "magicLink_email")

        let userDataStorage = makeUserDataStorage()

        XCTAssertEqual(userDataStorage.userData, .init(id: "userId", jwtToken: "jwt"))
        XCTAssertEqual(userDataStorage.clientUserData, .init(id: "clientUserId"))
        XCTAssertNil(securedStorage["magicLink_email"])
    }

    func testAnEmptyStorageIsReadable() {
        let userDataStorage = makeUserDataStorage()

        XCTAssertNil(userDataStorage.userData)
        XCTAssertFalse(userDataStorage.sessionIsUnreadable)
    }

    /// Before the device's first unlock after a reboot the Keychain cannot be read: the session is still there,
    /// it must not pass for an absent one.
    func testASessionLockedUntilFirstUnlockIsReportedAsUnreadable() throws {
        try storeSession()
        lock()

        let userDataStorage = makeUserDataStorage()

        XCTAssertTrue(userDataStorage.sessionIsUnreadable)
        XCTAssertNil(userDataStorage.userData)
    }

    func testTheSessionIsReadOnceTheDeviceIsUnlocked() throws {
        try storeSession()
        lock()
        let userDataStorage = makeUserDataStorage()

        mockSecuredStorage.readError = nil
        sessionReadTrigger.send()

        XCTAssertFalse(userDataStorage.sessionIsUnreadable)
        XCTAssertEqual(userDataStorage.userData, .init(id: "userId", clientId: "clientUserId", jwtToken: "jwt"))
        XCTAssertEqual(userDataStorage.clientUserData, .init(id: "clientUserId"))
    }

    func testAStillLockedSessionStaysReportedAsUnreadable() throws {
        try storeSession()
        lock()
        let userDataStorage = makeUserDataStorage()

        sessionReadTrigger.send()

        XCTAssertTrue(userDataStorage.sessionIsUnreadable)
        XCTAssertNil(userDataStorage.userData)
    }

    /// The unlock notification can be missed: whoever needs the session can try to read it again on its own.
    func testTheSessionCanBeReadAgainOnDemand() throws {
        try storeSession()
        lock()
        let userDataStorage = makeUserDataStorage()
        XCTAssertFalse(userDataStorage.readSessionIfUnreadable())

        mockSecuredStorage.readError = nil

        XCTAssertTrue(userDataStorage.readSessionIfUnreadable())
        XCTAssertEqual(userDataStorage.userData, .init(id: "userId", clientId: "clientUserId", jwtToken: "jwt"))
    }

    /// A read error that is not about the device being locked would not go away by waiting (an undecodable value,
    /// a missing entitlement…). As before, the session counts as absent, and a new one can replace it: waiting
    /// for it would leave the user with no session at all until the app is reinstalled.
    func testASessionUnreadableForAnotherReasonCountsAsAbsent() throws {
        try storeSession()
        mockSecuredStorage.readError = FakeError.undecodable

        let userDataStorage = makeUserDataStorage()

        XCTAssertFalse(userDataStorage.sessionIsUnreadable)
        XCTAssertNil(userDataStorage.userData)
        XCTAssertNil(userDataStorage.clientUserData)

        userDataStorage.store(userData: .init(id: "newUserId", jwtToken: "newJwt"))

        XCTAssertEqual(userDataStorage.userData, .init(id: "newUserId", jwtToken: "newJwt"))
    }

    /// Writing while the session cannot be read could replace a session not read yet: nothing is stored or
    /// changed, and the session read on unlock is the one stored before.
    func testNothingIsStoredWhileTheSessionIsUnreadable() throws {
        try storeSession()
        lock()
        let userDataStorage = makeUserDataStorage()
        // as if the device were unlocked between the read and the store
        mockSecuredStorage.readError = nil

        userDataStorage.store(userData: .init(id: "guestId", jwtToken: "guestJwt"))
        userDataStorage.store(clientUserData: nil)

        XCTAssertNil(userDataStorage.userData)
        XCTAssertEqual(try securedStorage.value(forKey: "user_jwtToken"), "jwt")
        XCTAssertEqual(try securedStorage.value(forKey: "client_user_id"), "clientUserId")

        sessionReadTrigger.send()

        XCTAssertEqual(userDataStorage.userData, .init(id: "userId", clientId: "clientUserId", jwtToken: "jwt"))
        XCTAssertEqual(userDataStorage.clientUserData, .init(id: "clientUserId"))
    }

    /// A session readable from the start never needs reading again: the triggers are not even watched.
    func testNoTriggerIsWatchedWhenTheSessionIsReadable() throws {
        try storeSession()
        var subscribed = false
        let triggers = sessionReadTrigger
            .handleEvents(receiveSubscription: { _ in subscribed = true })
            .eraseToAnyPublisher()

        _ = UserDataStorage(injector: injector, sessionReadTriggers: triggers)

        XCTAssertFalse(subscribed)
    }

    /// The triggers are watched while the session is unreadable, and dropped once it is read: it never becomes
    /// unreadable again.
    func testTheTriggersAreDroppedOnceTheSessionIsRead() throws {
        try storeSession()
        lock()
        var cancelled = false
        let triggers = sessionReadTrigger
            .handleEvents(receiveCancel: { cancelled = true })
            .eraseToAnyPublisher()
        let userDataStorage = UserDataStorage(injector: injector, sessionReadTriggers: triggers)

        sessionReadTrigger.send()
        XCTAssertFalse(cancelled, "still locked: the triggers are still needed")

        mockSecuredStorage.readError = nil
        sessionReadTrigger.send()

        XCTAssertTrue(cancelled)
        XCTAssertNotNil(userDataStorage.userData)
    }

    /// A trigger can fire as soon as it is subscribed to, on any thread: if the session is read then, the
    /// subscription is not kept, as it would never be dropped afterwards.
    func testTheTriggersAreNotKeptWhenTheSessionIsReadOnSubscribe() throws {
        try storeSession()
        lock()
        // locked for the read at init only
        mockSecuredStorage.readErrorLastsForReads = 1
        var cancelled = false
        let triggers = sessionReadTrigger
            .prepend(())
            .handleEvents(receiveCancel: { cancelled = true })
            .eraseToAnyPublisher()

        let userDataStorage = UserDataStorage(injector: injector, sessionReadTriggers: triggers)

        withExtendedLifetime(userDataStorage) {
            XCTAssertFalse(userDataStorage.sessionIsUnreadable)
            XCTAssertTrue(cancelled, "the subscription was kept although the session was read on subscribe")
        }
    }

    private var mockSecuredStorage: MockSecuredStorage { securedStorage as! MockSecuredStorage }

    private func makeUserDataStorage() -> UserDataStorage {
        UserDataStorage(injector: injector, sessionReadTriggers: sessionReadTrigger.eraseToAnyPublisher())
    }

    /// The Keychain as before the device's first unlock after a reboot.
    private func lock() {
        mockSecuredStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
    }

    private func storeSession() throws {
        try securedStorage.set("userId", key: "user_id")
        try securedStorage.set("jwt", key: "user_jwtToken")
        try securedStorage.set("clientUserId", key: "user_clientId")
        try securedStorage.set("clientUserId", key: "client_user_id")
    }
}

private enum FakeError: Error {
    case undecodable
}
