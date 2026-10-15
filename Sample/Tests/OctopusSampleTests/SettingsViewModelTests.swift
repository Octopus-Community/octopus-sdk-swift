//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import XCTest
@testable import OctopusSample

/// The Settings index: the SDK status line, the row summaries, the Reset confirmation, and the Language screen.
@MainActor
final class SettingsViewModelTests: XCTestCase {
    private let guest = SampleSession(hasProfile: true, isGuest: true, grantedEntitlements: [])
    private let signedIn = SampleSession(hasProfile: true, isGuest: false,
                                         grantedEntitlements: ["customer:premium", "customer:verified"])

    // MARK: - SDK status

    func testStatusFollowsStartSessionAndForceOffline() {
        XCTAssertEqual(SampleSDKStatus.of(isStarted: false, session: signedIn, isForcedOffline: true), .notStarted)
        XCTAssertEqual(SampleSDKStatus.of(isStarted: true, session: signedIn, isForcedOffline: true), .unreachable)
        XCTAssertEqual(SampleSDKStatus.of(isStarted: true, session: .none, isForcedOffline: false), .noSession)
        XCTAssertEqual(SampleSDKStatus.of(isStarted: true, session: guest, isForcedOffline: false), .guest)
        XCTAssertEqual(SampleSDKStatus.of(isStarted: true, session: signedIn, isForcedOffline: false), .signedIn)
        XCTAssertEqual(SampleSDKStatus.signedIn.label, "Running, signed in")
    }

    // MARK: - Summaries

    func testAccountSubtitleNamesTheSignedInUserAndCountsGrantedEntitlements() {
        let user = AppUser(userId: "user-1", nickname: "Ada")
        XCTAssertEqual(SettingsViewModel.accountSubtitle(appUser: user, session: signedIn),
                       "Connected as Ada · 2 entitlements")
        XCTAssertEqual(SettingsViewModel.accountSubtitle(appUser: AppUser(userId: "user-1"), session: signedIn),
                       "Connected as user-1 · 2 entitlements")
        XCTAssertEqual(SettingsViewModel.accountSubtitle(appUser: user, session: guest),
                       "Not connected · sign in with SSO")
        XCTAssertEqual(SettingsViewModel.accountSubtitle(appUser: nil, session: signedIn),
                       "Not connected · sign in with SSO")
    }

    func testEntitlementCountIsSpelledOut() {
        XCTAssertEqual(SettingsViewModel.entitlementCount(0), "None")
        XCTAssertEqual(SettingsViewModel.entitlementCount(1), "1 entitlement")
        XCTAssertEqual(SettingsViewModel.entitlementCount(3), "3 entitlements")
    }

    // MARK: - Reset

    func testResetAsksFirstAndClearsOnlyOnConfirm() {
        var resets = 0
        let viewModel = SettingsViewModel(observesApp: false, resetLocalSetup: { resets += 1 })

        viewModel.requestReset()
        XCTAssertTrue(viewModel.isResetConfirmationPresented)
        XCTAssertEqual(resets, 0)

        viewModel.confirmReset()
        XCTAssertFalse(viewModel.isResetConfirmationPresented)
        XCTAssertEqual(resets, 1)
    }

    func testCancellingTheResetClearsNothing() {
        var resets = 0
        let viewModel = SettingsViewModel(observesApp: false, resetLocalSetup: { resets += 1 })
        viewModel.requestReset()
        viewModel.isResetConfirmationPresented = false
        XCTAssertEqual(resets, 0)
    }

    // MARK: - Languages

    func testLanguageSummary() {
        XCTAssertEqual(SDKLanguages.summary(for: nil), "Follow system")
        XCTAssertEqual(SDKLanguages.summary(for: ""), "Follow system")
        XCTAssertEqual(SDKLanguages.summary(for: "fr"), "French (fr)")
        XCTAssertEqual(SDKLanguages.summary(for: "fr_BE"), "fr_BE")
    }

    func testShippedLanguagesAreUnique() {
        let codes = SDKLanguages.shipped.map(\.code)
        XCTAssertEqual(Set(codes).count, codes.count)
    }

    func testSettingsLanguagesFollowTheAndroidListAndAreAllShipped() {
        XCTAssertEqual(SDKLanguages.settingsList.map(\.name),
                       ["English", "French", "German", "Italian", "Polish", "Portuguese", "Spanish", "Swedish",
                        "Turkish"])
        XCTAssertEqual(SDKLanguages.settingsList.count, SDKLanguages.settingsCodes.count)
        let viewModel = LanguageSettingsViewModel(current: Just(nil).eraseToAnyPublisher(), apply: { _ in })
        XCTAssertEqual(viewModel.options.map(\.id), ["system"] + SDKLanguages.settingsCodes)
    }

    func testLanguageScreenListsFollowSystemFirstAndForwardsAChoice() throws {
        let current = CurrentValueSubject<Locale?, Never>(nil)
        var applied: [Locale?] = []
        let viewModel = LanguageSettingsViewModel(current: current.eraseToAnyPublisher(),
                                                  apply: { applied.append($0) })

        let system = try XCTUnwrap(viewModel.options.first)
        XCTAssertEqual(system.accessibilityId, "language-option-system")
        XCTAssertTrue(viewModel.isSelected(system))

        let german = try XCTUnwrap(viewModel.options.first { $0.id == "de" })
        viewModel.select(german)
        XCTAssertEqual(applied.last??.identifier, "de")
        XCTAssertTrue(viewModel.isSelected(german))
        XCTAssertFalse(viewModel.isSelected(system))

        viewModel.select(system)
        XCTAssertEqual(applied.count, 2)
        XCTAssertEqual(applied.last, .some(nil))
    }

    func testLanguageScreenFollowsAnOverrideSetElsewhere() throws {
        let current = CurrentValueSubject<Locale?, Never>(nil)
        let viewModel = LanguageSettingsViewModel(current: current.eraseToAnyPublisher(), apply: { _ in })
        current.send(Locale(identifier: "it"))
        let italian = try XCTUnwrap(viewModel.options.first { $0.id == "it" })
        XCTAssertTrue(viewModel.isSelected(italian))
    }
}
