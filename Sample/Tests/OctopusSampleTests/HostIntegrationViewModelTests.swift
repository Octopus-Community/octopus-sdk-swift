//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import XCTest
@testable import OctopusSample

/// Settings › Host app integration: the five callback rows in Android order, the wired count, the rows that
/// cannot be switched, and the actions reaching the store and the router.
@MainActor
final class HostIntegrationViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: HostIntegrationStore!
    private var profileWired: CurrentValueSubject<Bool, Never>!
    private var clientObjectWired = false
    private var restarts = 0

    override func setUp() {
        super.setUp()
        suiteName = "HostIntegrationViewModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = HostIntegrationStore(defaults: defaults)
        profileWired = CurrentValueSubject(false)
        clientObjectWired = false
        restarts = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    private func makeViewModel() -> HostIntegrationViewModel {
        HostIntegrationViewModel(store: store,
                                 profileWired: profileWired.eraseToAnyPublisher(),
                                 isClientObjectWired: { [unowned self] in clientObjectWired },
                                 restart: { [unowned self] in restarts += 1 })
    }

    func testRowsFollowTheAndroidOrderAndTestTags() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.rows.map(\.accessibilityId), [
            "host-integration-profile-switch",
            "host-integration-profile-edit-switch",
            "host-integration-login-switch",
            "host-integration-client-object-switch",
            "host-integration-group-access-denied-switch",
        ])
    }

    func testTheCountReadsWiredOverTotal() {
        let viewModel = makeViewModel()
        // Profile off (Unified Profile off), client object not wired: edit, login and group access are on.
        XCTAssertEqual(viewModel.countLabel, "3/5")
        XCTAssertEqual(viewModel.countAccessibilityLabel, "3 of 5 on")

        profileWired.send(true)
        XCTAssertEqual(viewModel.countLabel, "4/5")
    }

    func testLoginIsLockedOnAndOnlyTheHostOwnedCallbacksAreSwitchable() {
        let rows = HostIntegrationViewModel.rows(profileWired: false, profileEditWired: false,
                                                 clientObjectWired: false, groupAccessDeniedWired: false)
        let login = rows.first { $0.callback == .login }
        XCTAssertEqual(login?.isWired, true)
        XCTAssertEqual(login?.lock, .required("Required in SSO mode: the community does not open without it."))
        XCTAssertEqual(rows.filter(\.isSwitchable).map(\.callback), [.profileEdit, .groupAccessDenied])
    }

    func testSwitchingARowWritesTheStoreAndRebuildsTheRows() {
        let viewModel = makeViewModel()
        viewModel.set(.groupAccessDenied, wired: false)

        XCTAssertFalse(store.isGroupAccessDeniedWired)
        XCTAssertEqual(viewModel.rows.first { $0.callback == .groupAccessDenied }?.isWired, false)
        XCTAssertEqual(viewModel.rows.first { $0.callback == .groupAccessDenied }?.effect,
                       "Not handled by the app: tapping a locked group does nothing.")
    }

    func testALockedRowIgnoresASwitch() {
        let viewModel = makeViewModel()
        viewModel.set(.login, wired: false)
        viewModel.set(.profile, wired: true)
        XCTAssertEqual(viewModel.rows.first { $0.callback == .login }?.isWired, true)
        XCTAssertEqual(viewModel.rows.first { $0.callback == .profile }?.isWired, false)
    }

    func testRefreshPicksUpAClientObjectCallbackWiredElsewhere() {
        let viewModel = makeViewModel()
        clientObjectWired = true
        viewModel.refresh()
        XCTAssertEqual(viewModel.rows.first { $0.callback == .clientObject }?.isWired, true)
    }

    func testURLPolicyAndRestartReachTheStoreAndTheRouter() {
        let viewModel = makeViewModel()
        viewModel.select(.alwaysApp)
        XCTAssertEqual(store.urlPolicy, .alwaysApp)
        XCTAssertEqual(viewModel.urlPolicy, .alwaysApp)

        viewModel.restartNow()
        XCTAssertEqual(restarts, 1)
    }
}
