//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
@testable import OctopusCore

class UserDataCleanerMonitorTests: XCTestCase {
    /// Cleared by the cleaning, which makes it observable.
    private let clientUserPictureKey = "OctopusSDK.client.user.picture"
    /// Stands for the device being unlocked or the app coming back.
    private let sessionReadTrigger = PassthroughSubject<Void, Never>()

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: clientUserPictureKey)
        super.tearDown()
    }

    /// Before the device's first unlock after a reboot the session cannot be read: that is not a logout, and the
    /// user's data must survive it. Once the session can be read, an absent one is cleaned as before.
    func testAnUnreadableSessionIsNotCleanedAsALogout() async throws {
        let injector = makeInjector()
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        UserDefaults.standard.set(Data([1]), forKey: clientUserPictureKey)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        // leave time for a cleaning to happen if it were not waiting
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: clientUserPictureKey))

        // the device is unlocked, and there turns out to be no stored session
        securedStorage.readError = nil
        sessionReadTrigger.send()

        try await assertWithTimeout(UserDefaults.standard.data(forKey: clientUserPictureKey) == nil)
    }

    /// A session stored before the reboot that becomes readable on unlock is the user's: nothing is cleaned.
    func testAStoredSessionReadOnUnlockIsNotCleaned() async throws {
        let injector = makeInjector()
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try securedStorage.set("userId", key: "user_id")
        try securedStorage.set("jwt", key: "user_jwtToken")
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        UserDefaults.standard.set(Data([1]), forKey: clientUserPictureKey)
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)

        let monitor = UserDataCleanerMonitor(injector: injector)
        monitor.start()
        defer { monitor.stop() }
        securedStorage.readError = nil
        sessionReadTrigger.send()
        XCTAssertNotNil(userDataStorage.userData)
        // leave time for a cleaning to happen if one were triggered
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertNotNil(UserDefaults.standard.data(forKey: clientUserPictureKey))
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        let sessionReadTrigger = sessionReadTrigger
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .authProvider, .configRepository,
                               .appStateMonitor)
        injector.register {
            UserDataStorage(injector: $0, sessionReadTriggers: sessionReadTrigger.eraseToAnyPublisher())
        }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { NotificationsDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        return injector
    }
}
