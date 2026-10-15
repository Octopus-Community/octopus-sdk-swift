//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import XCTest
import Octopus
import OctopusCore
@testable import OctopusSample

/// The Scenarios tab: its catalogue, search, the toggles in its section headers and the labels its scenario
/// screens render, worded as on the Android sample.
@MainActor
final class ScenariosCatalogTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ScenariosCatalogTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Catalogue

    func testEveryScenarioBelongsToExactlyOneSectionInCatalogueOrder() {
        let listed = ScenarioCatalog.sections.flatMap(\.scenarios)
        XCTAssertEqual(listed.count, ScenarioID.allCases.count)
        XCTAssertEqual(Set(listed).count, listed.count)
        XCTAssertEqual(ScenarioCatalog.sections.map(\.title), [
            "Sign-in & user", "Presentation modes", "Community & groups", "Notifications", "Theme & language",
            "Host callbacks & events",
        ])
        XCTAssertEqual(ScenarioSection.sso.scenarios.first, .unifiedProfile)
    }

    func testEveryScenarioHasCopyAndUniqueTestIds() {
        for id in ScenarioID.allCases {
            let spec = id.spec
            XCTAssertEqual(spec.id, id)
            XCTAssertFalse(spec.title.isEmpty, "\(id)")
            XCTAssertFalse(spec.subtitle.isEmpty, "\(id)")
            XCTAssertFalse(spec.api.isEmpty, "\(id)")
            XCTAssertFalse(spec.youWillSee.isEmpty, "\(id)")
        }
        let cardIds = ScenarioID.allCases.map(\.spec.cardTestId)
        XCTAssertEqual(Set(cardIds).count, cardIds.count)
        XCTAssertEqual(ScenarioID.reactions.spec.cardTestId, "scenarios-reactions-card")
        XCTAssertEqual(ScenarioID.groups.spec.resultTestId, "groups-result")
        XCTAssertNil(ScenarioID.pushNotifications.spec.resultTestId)
    }

    func testOnlyTheSectionsWithASwitchCarryOne() {
        XCTAssertEqual(ScenarioSection.sso.toggle, .forceLogin)
        XCTAssertEqual(ScenarioSection.notifications.toggle, .pushRegistration)
        XCTAssertEqual(ScenarioCatalog.sections.compactMap(\.toggle).count, 2)
    }

    // MARK: - Search

    func testAnEmptyQueryListsEverySection() {
        XCTAssertEqual(ScenarioCatalog.filtered("").map(\.section), ScenarioCatalog.sections)
        XCTAssertEqual(ScenarioCatalog.filtered("   ").flatMap(\.scenarios).count, ScenarioID.allCases.count)
    }

    func testSearchMatchesTitleSubtitleApiAndIdCaseInsensitively() {
        let byTitle = ScenarioCatalog.filtered("BOTTOM SHEET").flatMap(\.scenarios).map(\.id)
        XCTAssertEqual(byTitle, [.sheet])
        let byId = ScenarioCatalog.filtered("syncFollowGroups").flatMap(\.scenarios).map(\.id)
        XCTAssertTrue(byId.contains(.syncFollowGroups))
    }

    func testSearchDropsEmptySections() {
        let result = ScenarioCatalog.filtered("bottom sheet")
        XCTAssertEqual(result.map(\.section), [.presentation])
        XCTAssertTrue(ScenarioCatalog.filtered("zzz-no-such-scenario").isEmpty)
    }

    /// The list's `ForEach` identifies groups by section and cards by scenario id: typing then clearing a query must
    /// keep those ids unique, in catalogue order and identical from one call to the next, so SwiftUI never sees two
    /// rows claim one identity nor a row change identity between two passes.
    func testSearchKeepsAStableUniqueIdentityFromTypingToClearing() {
        let full = ScenarioCatalog.filtered("")
        for query in ["", "p", "po", "post", "group", "e", "BOTTOM", "zzz-no-such-scenario", ""] {
            let result = ScenarioCatalog.filtered(query)
            let sections = result.map(\.section)
            XCTAssertEqual(Set(sections).count, sections.count, "duplicate section for \"\(query)\"")
            XCTAssertEqual(sections, ScenarioCatalog.sections.filter(sections.contains),
                           "sections out of catalogue order for \"\(query)\"")
            let ids = result.flatMap(\.scenarios).map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "duplicate scenario for \"\(query)\"")
            XCTAssertEqual(ScenarioCatalog.filtered(query).flatMap(\.scenarios).map(\.id), ids,
                           "unstable result for \"\(query)\"")
        }
        XCTAssertEqual(ScenarioCatalog.filtered("").map(\.section), full.map(\.section))
        XCTAssertEqual(ScenarioCatalog.filtered("").flatMap(\.scenarios).map(\.id),
                       full.flatMap(\.scenarios).map(\.id))
    }

    func testAnApiKeyIsMaskedToItsEnds() {
        XCTAssertEqual(ScenarioCatalog.maskApiKey(""), "—")
        XCTAssertEqual(ScenarioCatalog.maskApiKey("short"), "short")
        XCTAssertEqual(ScenarioCatalog.maskApiKey(" abcdefghijklmnop "), "abcd…mnop")
    }

    // MARK: - Feature toggles

    func testPushRegistrationIsOnByDefaultAndPersisted() {
        let toggles = FeatureToggles(defaults: defaults, sdkConfig: Just(nil).eraseToAnyPublisher(),
                                     internalDemoMode: true)
        XCTAssertTrue(toggles.isEnabled(.pushRegistration))
        XCTAssertTrue(toggles.isAvailable(.pushRegistration))
        toggles.setPushRegistrationEnabled(false)
        let relaunched = FeatureToggles(defaults: defaults, sdkConfig: Just(nil).eraseToAnyPublisher(),
                                        internalDemoMode: true)
        XCTAssertFalse(relaunched.isEnabled(.pushRegistration))
    }

    func testForceLoginIsReadFromTheConfigAndOnlyAvailableWhereItApplies() {
        let sso = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: true))
        XCTAssertTrue(FeatureToggles.forceLogin(of: sso))
        XCTAssertFalse(FeatureToggles.forceLogin(of: nil))
        XCTAssertTrue(FeatureToggles.isForceLoginAvailable(config: sso, internalDemoMode: true))
        XCTAssertFalse(FeatureToggles.isForceLoginAvailable(config: sso, internalDemoMode: false))
        XCTAssertFalse(FeatureToggles.isForceLoginAvailable(config: nil, internalDemoMode: true))
    }

    func testToggleLinesNameTheirEffect() {
        XCTAssertEqual(FeatureToggle.forceLogin.stateLine(enabled: true), "Force login is on")
        XCTAssertEqual(FeatureToggle.pushRegistration.stateLine(enabled: false), "Push registration is off")
        XCTAssertEqual(FeatureToggle.forceLogin.testId, "scenarios-toggle-force-login")
        for toggle in FeatureToggle.allCases {
            XCTAssertNotEqual(toggle.effectLine(enabled: true), toggle.effectLine(enabled: false))
        }
    }

    // MARK: - Override labels

    func testProfileFieldsLockLabels() {
        XCTAssertEqual(OverrideLabels.lockLabel(.allEditable), "All editable (default / no-op)")
        let lock = ProfileFieldsLock(nickname: .readOnly, avatar: .editable, bio: .disabled)
        XCTAssertEqual(OverrideLabels.lockLabel(lock), "nickname=READ_ONLY, avatar=EDITABLE, bio=DISABLED")
        XCTAssertEqual(OverrideLabels.lockLine(lock), "nickname read-only · avatar editable · bio hidden")
    }

    func testContentOptionsPresetsAreDistinctAndNamed() {
        let presets = OverrideLabels.contentOptionsPresets
        XCTAssertEqual(presets.count, 7)
        XCTAssertEqual(presets.first?.options, .allEnabled)
        for (index, preset) in presets.enumerated() {
            XCTAssertEqual(OverrideLabels.contentOptionsLabel(preset.options), preset.label)
            XCTAssertFalse(presets[(index + 1)...].contains { $0.options == preset.options }, preset.label)
        }
    }

    func testTermsLabels() {
        XCTAssertEqual(OverrideLabels.termsLabel(.explicitMultiCheckbox), "explicit · multi checkbox")
        XCTAssertEqual(OverrideLabels.termsLine(.implicit), "implicit (legal footer)")
        XCTAssertEqual(OverrideLabels.termsLine(.explicitSingleCheckbox), "explicit · single checkbox")
    }

    // MARK: - Consent texts scenario (same ids, order, labels and texts as the Android sample)

    func testConsentTextsScenarioFollowsTermsAcceptance() throws {
        let sso = ScenarioSection.sso.scenarios
        let termsIndex = try XCTUnwrap(sso.firstIndex(of: .termsAcceptance))
        XCTAssertEqual(sso[termsIndex + 1], .consentTexts)
        let spec = ScenarioID.consentTexts.spec
        XCTAssertEqual(spec.cardTestId, "scenarios-consentTexts-card")
        XCTAssertEqual(spec.resultTestId, "consentTexts-result")
        XCTAssertEqual(spec.api, "debugOverrideConsentTexts")
        XCTAssertTrue(spec.verifiable)
    }

    func testConsentTextsPresetsMatchTheSharedCatalog() {
        let presets = ConsentTextsPresets.all
        XCTAssertEqual(presets.map(\.testId), (1...8).map { "qa-preset-consentTexts-\($0)" })
        XCTAssertEqual(presets.map(\.label), [
            "Implicit — short notice with a link",
            "Multi checkbox — short labels with links",
            "Single checkbox — short label and text below",
            "Implicit — long notice (scrolls past 5 lines)",
            "Multi checkbox — long labels, several links",
            "Single checkbox — long, multi-paragraph",
            "Single checkbox — empty fields (SDK wordings)",
            "Multi checkbox with implicit texts (SDK wordings)",
        ])
        XCTAssertEqual(presets.map(\.mode), [
            .implicit, .explicitMultiCheckbox, .explicitSingleCheckbox, .implicit, .explicitMultiCheckbox,
            .explicitSingleCheckbox, .explicitSingleCheckbox, .explicitMultiCheckbox,
        ])
        // Preset 8 pairs the multi-checkbox mode with implicit texts: the SDK wordings must show.
        XCTAssertEqual(presets[7].texts, .implicit(notice: presets[0].texts.implicitNoticeForTests))
        XCTAssertEqual(presets[6].texts, .singleCheckbox(label: "", belowText: "   "))
        XCTAssertEqual(ConsentTextsPresets.clearTestId, "qa-preset-consentTexts-clear")
    }

    func testConsentTextsDescriptions() {
        XCTAssertEqual(ConsentTextsPresets.describe(nil), "no texts (SDK wordings)")
        XCTAssertEqual(ConsentTextsPresets.describe(.implicit(notice: " ")), "implicit texts · notice empty")
        let multi = ConsentTexts.multiCheckbox(termsLabel: "T", privacyLabel: nil, rulesLabel: "R")
        XCTAssertEqual(ConsentTextsPresets.describe(multi), "multi checkbox texts · 2/3 labels set")
        XCTAssertEqual(ConsentTextsPresets.describe(.singleCheckbox(label: "L", belowText: "")),
                       "single checkbox texts · label set, text below empty")
        XCTAssertEqual(ConsentTextsPresets.modeLabel(.explicitSingleCheckbox), "single checkbox")
    }

    func testConsentTextsPresetsLinkOnlyToExampleDomains() throws {
        // The sample is public: its presets must never point at a real community's documents.
        let linkPattern = try NSRegularExpression(pattern: "\\]\\((https?://[^)]+)\\)")
        for preset in ConsentTextsPresets.all {
            let texts: [String?]
            switch preset.texts {
            case let .implicit(notice): texts = [notice]
            case let .multiCheckbox(terms, privacy, rules): texts = [terms, privacy, rules]
            case let .singleCheckbox(label, below): texts = [label, below]
            }
            for text in texts.compactMap({ $0 }) {
                let range = NSRange(text.startIndex..., in: text)
                for match in linkPattern.matches(in: text, range: range) {
                    let url = (text as NSString).substring(with: match.range(at: 1))
                    XCTAssertTrue(url.hasPrefix("https://example.com/"), "\(preset.label): \(url)")
                }
            }
        }
    }

    // MARK: - Scenario screens

    func testTheResultBadgeNamesTheOutcomeAndItsDuration() {
        XCTAssertEqual(CodeResultBlock.badgeLabel(isError: false, durationMs: 124), "Success · 124 ms")
        XCTAssertEqual(CodeResultBlock.badgeLabel(isError: true, durationMs: nil), "Failure")
    }

    func testAContainerOpensOnThePostItNamesOrOnTheFeed() {
        guard case .mainFeed = CommunityEntry.initialScreen(postId: nil) else { return XCTFail("nil") }
        guard case .mainFeed = CommunityEntry.initialScreen(postId: "  ") else { return XCTFail("blank") }
        guard case .post = CommunityEntry.initialScreen(postId: " post-1 ") else { return XCTFail("post") }
    }

    func testSyncFollowStatusesAreNamedAsOnAndroid() {
        XCTAssertEqual(SyncFollowSummary.describe([]), "no action sent")
        XCTAssertEqual(SyncFollowSummary.name(.applied), "Applied")
        XCTAssertEqual(SyncFollowSummary.name(.groupNotFound), "GroupNotFound")
        XCTAssertEqual(SyncFollowSummary.name(.alreadyUnfollowed), "AlreadyUnfollowed")
    }

    func testTheUnifiedProfileModesMapToTheOverride() {
        typealias Mode = UnifiedProfileViewModel.Mode
        XCTAssertNil(Mode.backend.overrideValue)
        XCTAssertEqual(Mode.forceActive.overrideValue, true)
        XCTAssertEqual(Mode.forceInactive.overrideValue, false)
        for mode in Mode.allCases {
            XCTAssertEqual(Mode(overrideValue: mode.overrideValue), mode)
        }
        XCTAssertEqual(UnifiedProfileViewModel.effectLine(active: true), "Profile taps open Client profile")
    }

    func testTheUnifiedProfileScenarioFollowsItsManager() {
        let manager = UnifiedProfileManager(defaults: defaults, wireProfileCallback: { _ in })
        let viewModel = UnifiedProfileViewModel(manager: manager)
        XCTAssertFalse(viewModel.isActive)
        viewModel.setEnabled(true)
        XCTAssertTrue(viewModel.isEnabled)
        XCTAssertTrue(viewModel.isActive)
        viewModel.apply(.forceInactive)
        XCTAssertEqual(viewModel.appliedMode, .forceInactive)
        XCTAssertFalse(viewModel.isActive)
    }
}

private extension ConsentTexts {
    /// The notice of implicit texts, `nil` for the other cases.
    var implicitNoticeForTests: String? {
        guard case let .implicit(notice) = self else { return nil }
        return notice
    }
}
