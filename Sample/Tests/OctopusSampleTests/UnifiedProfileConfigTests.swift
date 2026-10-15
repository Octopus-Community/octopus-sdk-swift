//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusSample

/// The Config screen's Unified profile switch and the config it saves: one switch for both host-side inputs, a
/// status line built from the live state, and a save that keeps what this screen does not edit.
@MainActor
final class UnifiedProfileConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var wiring: [Bool] = []

    override func setUp() {
        super.setUp()
        suiteName = "UnifiedProfileConfigTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        wiring = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeManager() -> UnifiedProfileManager {
        UnifiedProfileManager(defaults: defaults, wireProfileCallback: { [unowned self] in wiring.append($0) })
    }

    // MARK: - State

    func testTheSwitchOnForcesTheFlagAndWiresTheCallback() {
        let state = UnifiedProfileHostState.switched(true)
        XCTAssertEqual(state.exposeClientUserIdOverride, true)
        XCTAssertTrue(state.profileCallbackWired)
        XCTAssertTrue(state.isSwitchOn)
    }

    func testTheSwitchOffClearsTheOverrideAndUnwiresTheCallback() {
        let state = UnifiedProfileHostState.switched(false)
        XCTAssertNil(state.exposeClientUserIdOverride)
        XCTAssertFalse(state.profileCallbackWired)
        XCTAssertFalse(state.isSwitchOn)
    }

    func testTheSwitchReadsOnOnlyWhenBothInputsAreSet() {
        let partialStates = [
            UnifiedProfileHostState(exposeClientUserIdOverride: true, profileCallbackWired: false),
            UnifiedProfileHostState(exposeClientUserIdOverride: nil, profileCallbackWired: true),
            UnifiedProfileHostState(exposeClientUserIdOverride: false, profileCallbackWired: true),
        ]
        for state in partialStates {
            XCTAssertFalse(state.isSwitchOn, "\(state)")
        }
    }

    func testTheStatusLineDescribesEveryLiveState() {
        XCTAssertTrue(UnifiedProfileHostState.switched(true).statusLine.hasPrefix("On:"))
        XCTAssertTrue(UnifiedProfileHostState.switched(false).statusLine.hasPrefix("Off:"))
        // Off whatever the flag says once the callback is unwired: the gate needs both.
        let unwired = UnifiedProfileHostState(exposeClientUserIdOverride: true, profileCallbackWired: false)
        XCTAssertTrue(unwired.statusLine.hasPrefix("Off:"))
        XCTAssertTrue(unwired.statusLine.contains("not wired"))
        let forcedOff = UnifiedProfileHostState(exposeClientUserIdOverride: false, profileCallbackWired: true)
        XCTAssertTrue(forcedOff.statusLine.hasPrefix("Off:"))
        XCTAssertTrue(forcedOff.statusLine.contains("forced off"))
        let backend = UnifiedProfileHostState(exposeClientUserIdOverride: nil, profileCallbackWired: true)
        XCTAssertTrue(backend.statusLine.contains("backend flag decides"))
    }

    // MARK: - Manager

    func testAFreshInstallStartsOff() {
        let manager = makeManager()
        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(manager.state, .switched(false))
    }

    func testTheSwitchIsAppliedAtOnceAndSurvivesARelaunch() {
        let manager = makeManager()
        manager.setEnabled(true)
        XCTAssertEqual(manager.state, .switched(true))
        XCTAssertEqual(wiring, [true])

        let relaunched = makeManager()
        XCTAssertTrue(relaunched.isEnabled)
        XCTAssertEqual(relaunched.state, .switched(true))
    }

    func testTurningTheSwitchOffUnwiresTheCallback() {
        let manager = makeManager()
        manager.setEnabled(true)
        manager.setEnabled(false)
        XCTAssertEqual(manager.state, .switched(false))
        XCTAssertEqual(wiring, [true, false])
        XCTAssertFalse(makeManager().isEnabled)
    }

    func testTheScenarioControlsAreTransientAndGiveWayToTheSwitch() {
        let manager = makeManager()
        manager.setEnabled(true)
        manager.setExposeClientUserIdOverride(false)
        manager.setProfileCallbackWired(false)
        XCTAssertEqual(manager.state,
                       UnifiedProfileHostState(exposeClientUserIdOverride: false, profileCallbackWired: false))
        XCTAssertTrue(manager.isEnabled, "only the switch is persisted")

        manager.restorePersistedState()
        XCTAssertEqual(manager.state, .switched(true))
        XCTAssertEqual(wiring.last, true)
    }

    // MARK: - Config screen

    func testTheConfigLineFollowsTheLiveStateNotTheLastSave() {
        let manager = makeManager()
        let viewModel = SDKConfigViewModel(savedConfig: { nil }, unifiedProfileManager: manager)
        XCTAssertFalse(viewModel.unifiedProfile.isSwitchOn)

        viewModel.setUnifiedProfileEnabled(true)
        XCTAssertTrue(viewModel.unifiedProfile.isSwitchOn)
        XCTAssertTrue(viewModel.unifiedProfile.statusLine.hasPrefix("On:"))

        // A change made elsewhere (the Unified Profile scenario) reaches the line too.
        manager.setProfileCallbackWired(false)
        XCTAssertFalse(viewModel.unifiedProfile.isSwitchOn)
        XCTAssertTrue(viewModel.unifiedProfile.statusLine.hasPrefix("Off:"))
    }

    func testTheFieldsStartFromTheSavedConfig() {
        let saved = SDKConfig(authKind: .sso(appManagedFields: [.nickname, .picture], forceLoginOnStrongActions: true))
        let viewModel = SDKConfigViewModel(savedConfig: { saved }, unifiedProfileManager: makeManager())
        XCTAssertTrue(viewModel.nicknameIsAssociated)
        XCTAssertFalse(viewModel.bioIsAssociated)
        XCTAssertTrue(viewModel.pictureIsAssociated)
        XCTAssertTrue(viewModel.forceLoginOnStringAction)
        XCTAssertTrue(viewModel.canSave)
    }

    func testTheFieldsStartOffWithoutASavedConfig() {
        let viewModel = SDKConfigViewModel(savedConfig: { nil }, unifiedProfileManager: makeManager())
        XCTAssertFalse(viewModel.nicknameIsAssociated)
        XCTAssertFalse(viewModel.bioIsAssociated)
        XCTAssertFalse(viewModel.pictureIsAssociated)
        XCTAssertFalse(viewModel.forceLoginOnStringAction)
    }

    func testASaveKeepsTheFeatureEnvItDoesNotEdit() throws {
        let env = FeatureEnvSelection(envName: "env", ticket: nil, apiHost: "host", expiresAt: Date.distantFuture,
                                      communityId: "id", communityName: "name", apiKey: "key")
        var saved = SDKConfig(authKind: .sso(appManagedFields: []), featureEnv: env)
        let viewModel = SDKConfigViewModel(savedConfig: { saved }, unifiedProfileManager: makeManager())
        viewModel.nicknameIsAssociated = true
        viewModel.bioIsAssociated = true
        viewModel.pictureIsAssociated = true

        XCTAssertEqual(viewModel.makeConfig().featureEnv, env)
        guard case let .sso(fields, _) = viewModel.makeConfig().authKind else { return XCTFail("SSO expected") }
        XCTAssertEqual(fields, [.nickname, .bio, .picture])

        // Read again on save: an env cleared while the screen stayed open stays cleared.
        saved = saved.with(featureEnv: nil)
        XCTAssertNil(viewModel.makeConfig().featureEnv)
    }

    // MARK: - Scenario

    func testTheScenarioShowsWhatTheSwitchSet() {
        let manager = makeManager()
        manager.setEnabled(true)
        let viewModel = UnifiedProfileViewModel(manager: manager)
        XCTAssertEqual(viewModel.appliedMode, .forceActive)
        XCTAssertTrue(viewModel.callbackWired)

        viewModel.apply(.forceInactive)
        XCTAssertEqual(manager.state.exposeClientUserIdOverride, false)
        XCTAssertEqual(viewModel.appliedMode, .forceInactive)
    }
}
