//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The groups of the Scenarios list, in the Android sample's order, names and ids.
enum ScenarioSection: String, CaseIterable, Identifiable {
    case sso
    case presentation
    case community
    case notifications
    case theme
    case host

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sso: "Sign-in & user"
        case .presentation: "Presentation modes"
        case .community: "Community & groups"
        case .notifications: "Notifications"
        case .theme: "Theme & language"
        case .host: "Host callbacks & events"
        }
    }

    /// The feature toggle the section header carries, if any.
    var toggle: FeatureToggle? {
        switch self {
        case .sso: .forceLogin
        case .notifications: .pushRegistration
        default: nil
        }
    }

    var testId: String { "scenarios-section-\(rawValue)" }

    var scenarios: [ScenarioID] { ScenarioID.allCases.filter { $0.section == self } }
}

/// One scenario of the list. The raw value is the id shared with the Android sample and the QA catalog.
enum ScenarioID: String, CaseIterable, Identifiable {
    // Sign-in & user
    case unifiedProfile
    case connection
    case communityData
    case profileFieldsLock
    case termsAcceptance
    case consentTexts
    case forceNicknameChoice
    case refreshEntitlements
    // Presentation modes
    case initialScreen
    case fullscreen
    case modal
    case sheet
    // Community & groups
    case groups
    case syncFollowGroups
    case communityAccess
    case bridge
    case createPost
    case reactions
    case contentOptions
    case groupAccessDenied
    case screenStates
    case groupSections
    // Notifications
    case notSeenNotifications
    case pushNotifications
    // Theme & language
    case locale
    case theme
    // Host callbacks & events
    case customEvents
    case lifecycle
    case events
    case trackABTests
    case forceOctopusABTests

    var id: String { rawValue }

    var section: ScenarioSection {
        switch self {
        case .unifiedProfile, .connection, .communityData, .profileFieldsLock, .termsAcceptance, .consentTexts,
             .forceNicknameChoice, .refreshEntitlements:
            .sso
        case .initialScreen, .fullscreen, .modal, .sheet:
            .presentation
        case .groups, .syncFollowGroups, .communityAccess, .bridge, .createPost, .reactions, .contentOptions,
             .groupAccessDenied, .screenStates, .groupSections:
            .community
        case .notSeenNotifications, .pushNotifications:
            .notifications
        case .locale, .theme:
            .theme
        case .customEvents, .lifecycle, .events, .trackABTests, .forceOctopusABTests:
            .host
        }
    }

    var spec: ScenarioSpec { ScenarioCatalog.spec(for: self) }
}

/// A parameter of the call a scenario makes, shown in its Parameters block.
struct ScenarioParameter: Equatable {
    let name: String
    let type: String
    let value: String
}

/// The copy and wiring facts of one scenario.
struct ScenarioSpec: Equatable {
    let id: ScenarioID
    let title: String
    let subtitle: String
    /// The SDK symbol the scenario exercises, or the host container for a presentation mode.
    let api: String
    let youWillSee: String
    var note: String?
    var parameters: [ScenarioParameter] = []
    /// Whether the scenario owns a Result zone fed by its call.
    var hasResult = false
    /// Whether the detail screen ends with "Verify in Community".
    var verifiable = false
    /// Label of the run button, for the scenarios that have one.
    var runLabel: String?

    /// Test id of the Result zone's code block. Android leaves the push scenario's untagged.
    var resultTestId: String? { id == .pushNotifications ? nil : "\(id.rawValue)-result" }
    var cardTestId: String { "scenarios-\(id.rawValue)-card" }

    /// Case-insensitive match on title, subtitle, API name and id, as on Android.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [title, subtitle, api, id.rawValue].contains { $0.range(of: query, options: .caseInsensitive) != nil }
    }
}

enum ScenarioCatalog {
    static let sections = ScenarioSection.allCases

    /// The scenarios matching `query`, grouped by section, empty sections dropped.
    static func filtered(_ query: String) -> [(section: ScenarioSection, scenarios: [ScenarioSpec])] {
        sections.compactMap { section in
            let specs = section.scenarios.map(\.spec).filter { $0.matches(query) }
            return specs.isEmpty ? nil : (section, specs)
        }
    }

    /// "abcd…wxyz": enough to tell two keys apart, never enough to reuse one.
    static func maskApiKey(_ key: String) -> String {
        let key = key.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return "—" }
        guard key.count >= 10 else { return key }
        return "\(key.prefix(4))…\(key.suffix(4))"
    }

    private static let hasAccess = ScenarioParameter(name: "hasAccess", type: "Boolean",
                                                     value: "true to grant, false to deny")

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func spec(for id: ScenarioID) -> ScenarioSpec {
        switch id {
        case .unifiedProfile:
            ScenarioSpec(
                id: id, title: "Unified Profile",
                subtitle: "Open member profiles in the host app or in the community.",
                api: "onNavigateToProfileCallback",
                youWillSee: "with the switch on, a member with an app id opens Client profile and the home profile " +
                    "button opens Activity; with it off, both open native profiles.",
                verifiable: true)
        case .connection:
            ScenarioSpec(
                id: id, title: "Sign in and out as the demo user",
                subtitle: "The community shows the demo user as signed in: they can post, react and be notified.",
                api: "connectUser",
                youWillSee: "the Community tab greets the demo user, and the composer unlocks.",
                note: "Presets 2-4 (sign in as Premium / Moderator / both) need entitlement injection the sign-in " +
                    "call does not take today — only presets 1 and 5 are built.",
                parameters: [.init(name: "user", type: "ClientUser",
                                   value: "the SSO user stored on the Account screen")],
                hasResult: true, verifiable: true)
        case .communityData:
            ScenarioSpec(
                id: id, title: "Read a member's community profile",
                subtitle: "The member's community profile comes back, and keeps updating while you watch it.",
                api: "fetchCommunityData",
                youWillSee: "the member's nickname and ids, refreshing as they change.",
                parameters: [.init(name: "clientUserId", type: "String",
                                   value: "the connected profile's id, or the id typed below")])
        case .profileFieldsLock:
            ScenarioSpec(
                id: id, title: "Lock the profile fields the host owns",
                subtitle: "The locked fields turn read-only in the community's profile editor.",
                api: "debugOverrideProfileFieldsLock",
                youWillSee: "the locked fields greyed out in the profile editor.",
                verifiable: true)
        case .termsAcceptance:
            ScenarioSpec(
                id: id, title: "Change how members accept the terms",
                subtitle: "The community asks for consent the way you picked, or stops asking altogether.",
                api: "debugOverrideTermsAcceptanceMode",
                youWillSee: "the consent step in the form you chose, or no consent step at all.",
                verifiable: true)
        case .consentTexts:
            ScenarioSpec(
                id: id, title: "Show the community's consent wording",
                subtitle: "The consent step shows the wording the community wrote, links included.",
                api: "debugOverrideConsentTexts",
                youWillSee: "the community's own consent texts, or the SDK wording where a text is empty.",
                verifiable: true)
        case .forceNicknameChoice:
            ScenarioSpec(
                id: id, title: "Require a nickname before the first contribution",
                subtitle: "A member without a confirmed nickname types one before their first post, comment or "
                    + "reply.",
                api: "debugOverrideForceNicknameChoice",
                youWillSee: "the nickname choice screen with an empty field, before the contribution is sent.",
                verifiable: true)
        case .refreshEntitlements:
            ScenarioSpec(
                id: id, title: "Re-issue the demo user's entitlements",
                subtitle: "The community picks up the entitlements you edited, without signing out.",
                api: "refreshEntitlements",
                youWillSee: "the abilities you granted, available in the community.",
                verifiable: true)
        case .initialScreen:
            ScenarioSpec(
                id: id, title: "Open the community on a chosen screen",
                subtitle: "The community opens directly on the member, profile or feed you picked.",
                api: "OctopusHomeScreen(initialScreen:)",
                youWillSee: "the community already on the screen you asked for.",
                note: "Post, group and pre-filled composer open from the first screen below, member activity by " +
                    "app id and the own profile from the second. Standalone post details and the post editor " +
                    "have no initial screen in the iOS SDK.")
        case .fullscreen:
            ScenarioSpec(
                id: id, title: "Open the community full screen",
                subtitle: "The community takes the whole screen, outside the tab bar.",
                api: "host: full-screen cover",
                youWillSee: "the community covering the screen; the Back that leads its header returns here.",
                note: "Preset 3 puts a host bottom bar under it: the embedded content must clear the bar and its " +
                    "safe-area inset.")
        case .modal:
            ScenarioSpec(
                id: id, title: "Open the community as a modal",
                subtitle: "The community covers the screen in a host-owned modal that you close yourself.",
                api: "host: fullScreenCover",
                youWillSee: "the community in a modal, closed by the X that leads the community's header.")
        case .sheet:
            ScenarioSpec(
                id: id, title: "Open the community as a bottom sheet",
                subtitle: "The community slides over this screen; swipe down to come back.",
                api: "host: sheet",
                youWillSee: "the community at sheet height, its own navigation staying inside the sheet.")
        case .groups:
            ScenarioSpec(
                id: id, title: "Browse the community's groups",
                subtitle: "Every group the community offers, with whether the demo user follows it.",
                api: "fetchGroups",
                youWillSee: "the group list, with a follow state on each row.",
                hasResult: true, verifiable: true, runLabel: "Run fetchGroups()")
        case .syncFollowGroups:
            ScenarioSpec(
                id: id, title: "Follow or unfollow every group at once",
                subtitle: "The follow state of every group flips in one call, and the community reflects it.",
                api: "syncFollowGroups",
                youWillSee: "every group's follow state matching what you just applied.",
                parameters: [.init(name: "actions", type: "[OctopusSyncFollowGroup.Action]",
                                   value: "one action per followable group, dated now + the offset picked below")],
                hasResult: true, verifiable: true)
        case .communityAccess:
            ScenarioSpec(
                id: id, title: "Grant or deny access to the community",
                subtitle: "The community either opens normally, or shows its no-access state.",
                api: "overrideCommunityAccess",
                youWillSee: "the community opening, or its no-access screen.",
                parameters: [hasAccess],
                hasResult: true, verifiable: true)
        case .bridge:
            ScenarioSpec(
                id: id, title: "Open the post attached to a product",
                subtitle: "A post tied to a host object opens — created on the spot the first time you ask for it.",
                api: "fetchOrCreateClientObjectRelatedPost",
                youWillSee: "the post for that object, and your reaction on it.",
                verifiable: true)
        case .createPost:
            ScenarioSpec(
                id: id, title: "Start a post from the host app",
                subtitle: "The composer opens pre-filled with the text, image or link the host handed over.",
                api: "OctopusInitialScreen.createPost",
                youWillSee: "the composer, pre-filled with what the host passed.",
                verifiable: true)
        case .reactions:
            ScenarioSpec(
                id: id, title: "React to a post from the host app",
                subtitle: "The reaction you picked shows on that post in the community.",
                api: "set(reaction:postId:)",
                youWillSee: "your reaction on the post you named.",
                verifiable: true)
        case .contentOptions:
            ScenarioSpec(
                id: id, title: "Change what members are allowed to post",
                subtitle: "The composer offers only the kinds of content the community allows.",
                api: "debugOverrideContentOptions",
                youWillSee: "the composer offering only the allowed content types.",
                verifiable: true)
        case .groupAccessDenied:
            ScenarioSpec(
                id: id, title: "Handle a member reaching a closed group",
                subtitle: "The host is told a group was refused, instead of the community handling it alone.",
                api: "set(groupAccessDeniedCallback:)",
                youWillSee: "the host's own access-denied screen instead of the SDK's.")
        case .screenStates:
            ScenarioSpec(
                id: id, title: "Screen states (offline)",
                subtitle: "Forces the SDK offline so the empty / error states, their Retry and the no-connection " +
                    "toast can be exercised in the simulator.",
                api: "debugOverrideConnectionAvailable",
                youWillSee: "the offline and retry states of each community screen.")
        case .groupSections:
            ScenarioSpec(
                id: id, title: "Group Sections",
                subtitle: "A community can group its groups into named client sections. The SDK renders each " +
                    "section title and a separator above every block except the first.",
                api: "debugOverrideTopicSections",
                youWillSee: "the groups list under the section headers you set.")
        case .notSeenNotifications:
            ScenarioSpec(
                id: id, title: "Set the unread notification count",
                subtitle: "The notification badge in the community carries the number you set.",
                api: "updateNotSeenNotificationsCount",
                youWillSee: "the notification badge carrying the count you sent.",
                hasResult: true, verifiable: true)
        case .pushNotifications:
            ScenarioSpec(
                id: id, title: "Open a post from a push notification",
                subtitle: "A simulated push is recognised as an Octopus one and opens the post it points at.",
                api: "isAnOctopusNotification",
                youWillSee: "the community opening on the post the notification named.",
                note: "The iOS SDK builds no notification payload for a test: this scenario opens the community on " +
                    "the post id directly, the screen a recognised push lands on.",
                hasResult: true)
        case .locale:
            ScenarioSpec(
                id: id, title: "Switch the community's language",
                subtitle: "The community's own labels switch to the language you picked.",
                api: "overrideDefaultLocale",
                youWillSee: "the community's buttons and labels in the language you picked.",
                parameters: [.init(name: "locale", type: "Locale?",
                                   value: "Locale(identifier: \"fr\"), Locale(identifier: \"en\"), or nil to reset")],
                hasResult: true, verifiable: true)
        case .theme:
            ScenarioSpec(
                id: id, title: "Apply the host's brand to the community",
                subtitle: "The community adopts the host's colours, fonts and logo — or drops back to the SDK's own " +
                    "look.",
                api: "OctopusTheme",
                youWillSee: "the community in the host's colours, or in the SDK's default look.",
                verifiable: true)
        case .customEvents:
            ScenarioSpec(
                id: id, title: "Send a custom analytics event",
                subtitle: "The event shows up in the Events log, with the properties you attached.",
                api: "track(customEvent:)",
                youWillSee: "the event at the top of the Events log.",
                parameters: [
                    .init(name: "customEvent", type: "CustomEvent", value: "name = \"sample_test_event\""),
                    .init(name: "customEvent.properties", type: "[String: CustomEvent.PropertyValue]",
                          value: "empty, or sample_prop = \"sample_value\""),
                ],
                hasResult: true)
        case .lifecycle:
            ScenarioSpec(
                id: id, title: "Restart or stop the SDK",
                subtitle: "The session ends and the community goes back to its not-connected state.",
                api: "reset / stop",
                youWillSee: "the community back in its not-connected state.",
                note: "The iOS SDK exposes no reset() or stop(): presets 2-3 stay disabled. Switching community, " +
                    "which rebuilds the SDK on another key, is built below.",
                parameters: [.init(name: "apiKey", type: "String", value: "picked below — switchCommunity only")],
                hasResult: true)
        case .events:
            ScenarioSpec(
                id: id, title: "Watch what the SDK reports",
                subtitle: "Every event the SDK emits, live, as the community is used.",
                api: "eventPublisher",
                youWillSee: "the event stream filling up as you use the community.")
        case .trackABTests:
            ScenarioSpec(
                id: id, title: "Report which cohort the member is in",
                subtitle: "The community opens for the cohort you granted, and refuses the other one.",
                api: "track(hasAccessToCommunity:)",
                youWillSee: "the community open, or the refusal the other cohort gets.",
                parameters: [hasAccess],
                runLabel: "Run track(hasAccessToCommunity: true)")
        case .forceOctopusABTests:
            ScenarioSpec(
                id: id, title: "Force Octopus's own A/B decision",
                subtitle: "The community's own access rule is overridden — granted or denied — until you clear it.",
                api: "overrideCommunityAccess",
                youWillSee: "the community following your forced value, not its own.",
                parameters: [hasAccess],
                hasResult: true, verifiable: true)
        }
    }
}
