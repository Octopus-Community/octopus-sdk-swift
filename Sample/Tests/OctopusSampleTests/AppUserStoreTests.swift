//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusSample

/// A Disconnect keeps the app's user but is remembered across launches, so the app does not sign that user back
/// in on its own; storing a user, or Reset configuration, ends it.
final class AppUserStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppUserStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testAFreshInstallIsNotSignedOut() {
        XCTAssertFalse(AppUserStore(defaults: defaults).isSignedOut)
    }

    func testASignOutSurvivesARelaunchAndKeepsTheUser() {
        let store = AppUserStore(defaults: defaults)
        store.set(user: AppUser(userId: "user-1", nickname: "Ada"))
        store.setSignedOut(true)

        let relaunched = AppUserStore(defaults: defaults)
        XCTAssertTrue(relaunched.isSignedOut)
        XCTAssertEqual(relaunched.user, AppUser(userId: "user-1", nickname: "Ada"))
    }

    func testStoringAUserEndsTheSignOut() {
        let store = AppUserStore(defaults: defaults)
        store.set(user: AppUser(userId: "user-1"))
        store.setSignedOut(true)

        store.set(user: AppUser(userId: "user-1"))

        XCTAssertFalse(store.isSignedOut)
        XCTAssertFalse(AppUserStore(defaults: defaults).isSignedOut)
    }

    func testClearingTheUserEndsTheSignOut() {
        let store = AppUserStore(defaults: defaults)
        store.set(user: AppUser(userId: "user-1"))
        store.setSignedOut(true)

        store.set(user: nil)

        let relaunched = AppUserStore(defaults: defaults)
        XCTAssertNil(relaunched.user)
        XCTAssertFalse(relaunched.isSignedOut)
    }

    func testTheSignOutIsClearedBeforeTheUserPublishes() {
        let store = AppUserStore(defaults: defaults)
        store.setSignedOut(true)
        var signedOutWhenPublished: [Bool] = []
        let subscription = store.$user.dropFirst().sink { _ in signedOutWhenPublished.append(store.isSignedOut) }

        store.set(user: AppUser(userId: "user-1"))

        XCTAssertEqual(signedOutWhenPublished, [false])
        subscription.cancel()
    }

    // MARK: - What the app connects

    func testTheStoredUserIsConnectedUnlessSignedOut() {
        let user = AppUser(userId: "user-1")
        XCTAssertEqual(AppUserManager.userToConnect(user, isSignedOut: false), user)
        XCTAssertNil(AppUserManager.userToConnect(user, isSignedOut: true))
        XCTAssertNil(AppUserManager.userToConnect(nil, isSignedOut: false))
    }
}
