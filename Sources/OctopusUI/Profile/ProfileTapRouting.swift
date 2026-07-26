//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// The three ways a profile tap can be handled (Unified Profile, OCT-1374).
enum ProfileTapTarget: Equatable {
    /// Hand the tap to the host's `onNavigateToProfileCallback` with the tapped member's client
    /// user id.
    case hostClientProfile

    /// Open the Octopus posts-only activity screen: Unified Profile is active but the member has no
    /// client id (guest / BO / admin), so the host has no profile to open for them.
    /// Name kept verbatim from Android's `OCTOPUS_ACTIVITY`; on iOS it opens the user-posts screen
    /// (`MainFlowScreen.activity`).
    case octopusActivity

    /// Open the SDK's native profile screen (Unified Profile inactive).
    case nativeProfile
}

/// Whether Unified Profile is active. **Both** conditions must hold: the community exposes client
/// user ids (`exposeClientUserId` — the backend config, i.e. the community opted in) AND the host
/// wired the profile-open callback (`onNavigateToProfileWired` — the app can actually open a client
/// profile). Either one missing → the SDK keeps its native profile screens everywhere; neither
/// signal activates the feature alone. Requiring both closes a footgun: the two flags are set by
/// different parties (the flag by Octopus/BE ops per community, the callback by the integrator in
/// app code), so wiring the callback before the flag is turned on — or vice-versa — must never
/// silently remove the native profile UI. Pure so the model lives in one place and mirrors verbatim
/// across iOS/Android/Flutter/RN.
///
/// - Parameters:
///   - exposeClientUserId: whether the backend community config exposes client user ids.
///   - onNavigateToProfileWired: whether the host wired `onNavigateToProfileCallback`.
func unifiedProfileActive(exposeClientUserId: Bool, onNavigateToProfileWired: Bool) -> Bool {
    exposeClientUserId && onNavigateToProfileWired
}

/// Resolves how a profile tap is handled once `unifiedActive` is known (see `unifiedProfileActive`):
/// inactive → the SDK's native profile; active with a client id → the host's own profile screen
/// (`onNavigateToProfileCallback`); active without one (guest / BO / admin) → the Octopus posts-only
/// activity. Pure so the routing stays unit-testable independently of the SwiftUI/dispatcher wiring.
///
/// - Parameters:
///   - unifiedActive: whether Unified Profile is active for this tap (see `unifiedProfileActive`).
///   - clientUserId: the tapped member's client user id, or `nil`.
func resolveProfileTapTarget(unifiedActive: Bool, clientUserId: String?) -> ProfileTapTarget {
    switch (unifiedActive, clientUserId) {
    case (false, _): return .nativeProfile
    case (true, .some): return .hostClientProfile
    case (true, .none): return .octopusActivity
    }
}

// MARK: - Dispatch

/// Single funnel for every profile tap inside the community (post/comment/reply headers, self-taps),
/// decided synchronously **before** any push so there is never a flash of a native screen.
///
/// Reads `exposeClientUserId` from the config repository's synchronous cached getter
/// (`communityConfig`) — not a Combine subscription — so the decision is available immediately, and
/// resolves the target via `resolveProfileTapTarget`:
/// - `.hostClientProfile` → invokes `octopus.onNavigateToProfileCallback` with `clientUserId` (the
///   wired callback and the non-nil id are guaranteed by `resolveProfileTapTarget`; the native
///   fallback is defensive only).
/// - `.octopusActivity` → pushes the posts-only user-posts screen for `profileId`.
/// - `.nativeProfile` → pushes the SDK's native profile screen (current-user graph for a self-tap,
///   public profile otherwise).
///
/// - Parameters:
///   - octopus: the SDK instance, used to read the config, the host callback and the connected user.
///   - navigator: the main-flow navigator used for native pushes.
///   - profileId: the tapped member's Octopus profile id, or `nil` when unknown (self-tap before the
///     profile has loaded).
///   - clientUserId: the tapped member's client user id, or `nil`.
@MainActor
func dispatchProfileTap(
    octopus: OctopusSDK,
    navigator: Navigator<MainFlowScreen>,
    profileId: String?,
    clientUserId: String?
) {
    let unifiedActive = unifiedProfileActive(
        exposeClientUserId: octopus.core.configRepository.communityConfig?.exposeClientUserId ?? false,
        onNavigateToProfileWired: octopus.onNavigateToProfileCallback != nil)

    switch resolveProfileTapTarget(unifiedActive: unifiedActive, clientUserId: clientUserId) {
    case .hostClientProfile:
        if let onNavigateToProfileCallback = octopus.onNavigateToProfileCallback, let clientUserId {
            onNavigateToProfileCallback(clientUserId)
        } else {
            pushNativeProfile(octopus: octopus, navigator: navigator, profileId: profileId)
        }
    case .octopusActivity:
        if let profileId {
            navigator.push(.activity(.profileId(profileId)))
        } else {
            pushNativeProfile(octopus: octopus, navigator: navigator, profileId: profileId)
        }
    case .nativeProfile:
        pushNativeProfile(octopus: octopus, navigator: navigator, profileId: profileId)
    }
}

/// Convenience for the "view my profile" self-tap affordances that do not carry a tapped author:
/// resolves the connected user's `profileId`/`clientUserId` from the SDK and dispatches like any
/// other profile tap (a self-tap with a client id also routes to the host when Unified Profile is
/// active; a guest with no client id lands on the posts-only member activity screen).
@MainActor
func dispatchCurrentUserProfileTap(octopus: OctopusSDK, navigator: Navigator<MainFlowScreen>) {
    let profile = octopus.core.profileRepository.profile
    dispatchProfileTap(octopus: octopus, navigator: navigator,
                       profileId: profile?.id, clientUserId: profile?.clientUserId)
}

// MARK: - Home floating button (connected user's own activity)

/// Where the home floating "my profile" button navigates (Unified Profile, OCT-1374).
///
/// Unlike ``dispatchCurrentUserProfileTap`` (used by the comment/reply composers), the floating button
/// never routes straight to the host: when Unified Profile is active it opens the SDK's own **Activity**
/// screen (whose overflow menu carries "View my profile" → host) — always on the Notifications tab,
/// because the button shows a bell (PO feedback, 2026-07-17). Otherwise it keeps opening the legacy
/// ``CurrentUserProfileSummaryView``, whose landing tab follows the unseen-notifications rule.
/// Mirrors Android's `OctopusDestination.Activity` / `CurrentUserProfileSummary`.
enum CurrentUserActivityDestination: Equatable {
    case activityNotifications
    case activityPosts
    case currentUserProfileNotifications
    case currentUserProfilePosts
}

/// Resolves the ``CurrentUserActivityDestination`` opened by the home floating button. Pure so the
/// feature-on/off × unseen-notifications routing stays unit-testable independently of the SwiftUI
/// wiring (mirrors Android's `currentUserActivityDestination`).
///
/// - Parameters:
///   - unifiedProfileEnabled: whether Unified Profile is active (see ``unifiedProfileActive``).
///   - hasUnseenNotifications: whether the connected user has at least one unseen notification.
func currentUserActivityDestination(unifiedProfileEnabled: Bool,
                                    hasUnseenNotifications: Bool) -> CurrentUserActivityDestination {
    switch (unifiedProfileEnabled, hasUnseenNotifications) {
    case (true, _): return .activityNotifications
    case (false, true): return .currentUserProfileNotifications
    case (false, false): return .currentUserProfilePosts
    }
}

/// Opens the home floating button's destination (see ``currentUserActivityDestination``): the Unified
/// Profile **Activity** screen (on the tab matching the unseen-notifications state) when active, or the
/// SDK's legacy own-profile screen otherwise. The legacy screen self-selects its initial tab from the
/// unseen-notifications count, so both legacy branches push the same screen.
@MainActor
func dispatchCurrentUserActivityTap(octopus: OctopusSDK, navigator: Navigator<MainFlowScreen>) {
    let unifiedProfileEnabled = unifiedProfileActive(
        exposeClientUserId: octopus.core.configRepository.communityConfig?.exposeClientUserId ?? false,
        onNavigateToProfileWired: octopus.onNavigateToProfileCallback != nil)
    let hasUnseenNotifications = (octopus.core.profileRepository.profile?.notificationBadgeCount ?? 0) > 0

    switch currentUserActivityDestination(unifiedProfileEnabled: unifiedProfileEnabled,
                                          hasUnseenNotifications: hasUnseenNotifications) {
    case .activityNotifications:
        navigator.push(.activity(.connectedUser(initialTab: .notifications)))
    case .activityPosts:
        navigator.push(.activity(.connectedUser(initialTab: .posts)))
    case .currentUserProfileNotifications, .currentUserProfilePosts:
        navigator.push(.currentUserProfile)
    }
}

/// Pushes the SDK's native profile screen: the current-user graph for a self-tap (or when the id is
/// unknown), the public profile otherwise.
@MainActor
private func pushNativeProfile(octopus: OctopusSDK, navigator: Navigator<MainFlowScreen>, profileId: String?) {
    if let profileId, profileId != octopus.core.profileRepository.profile?.id {
        navigator.push(.publicProfile(profileId: profileId))
    } else {
        navigator.push(.currentUserProfile)
    }
}
