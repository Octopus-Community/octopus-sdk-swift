//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus
import OctopusCore

/// Which tab the connected-user Activity screen opens on (Unified Profile, OCT-1374). Mirrors
/// Android's `selectedTabIndex` (0 = Notifications, 1 = Posts). Carried explicitly by the
/// `.connectedUser` source, and derived from the unseen-notifications rule when another entry point
/// resolves to the connected user (see ``ActivityViewModel/connectedUserInitialTab``).
enum ActivityTab: Hashable {
    case notifications
    case posts
}

/// How the "activity" screen (Unified Profile, OCT-1374) was opened.
enum ActivitySource: Hashable {
    /// A resolved Octopus profile id — the in-community profile-tap path (guest / BO / admin member),
    /// which knows the id synchronously and needs no lookup. Resolves to the connected-user mode when
    /// the id turns out to be the connected user's own (see ``resolveActivityMode``).
    case profileId(String)
    /// The host app's own client user id — the `OctopusInitialScreen.activity` entry point, resolved
    /// asynchronously to an Octopus id through the `GetPublicProfile` client-user-id lookup. Resolves
    /// to the connected-user mode when the id turns out to be the connected user's own.
    case clientUserId(String)
    /// The connected user's own activity — the home floating-button path (see
    /// ``currentUserActivityDestination``). Shows the two-tab "Activity" screen directly, no lookup.
    case connectedUser(initialTab: ActivityTab)
}

extension ActivitySource {
    /// Maps the public `OctopusInitialScreen.activity` payload to the internal source. The by-profileId
    /// entry point needs no lookup; the by-clientUserId one keeps its async resolution in the view
    /// model. The public entry points only ever open another member (or the connected user, resolved
    /// through ``resolveActivityMode``) — never the explicit `.connectedUser` source, which is
    /// internal to the floating button.
    init(_ source: OctopusInitialScreen.ActivityScreenInfo.Source) {
        switch source {
        case let .clientUserId(clientUserId): self = .clientUserId(clientUserId)
        case let .profileId(profileId): self = .profileId(profileId)
        }
    }
}

/// The three modes the activity screen can run in, resolved once the (possibly async) clientUserId →
/// Octopus-id lookup has settled (mirrors Android's `ActivityMode`: CONNECTED_USER / OTHER_USER /
/// CLIENT_LOOKUP_FAILED).
enum ActivityMode: Equatable {
    /// The connected user's own activity: the two-tab "Activity" screen (Notifications + Posts) with
    /// its overflow menu. Reached when no member was requested, or the requested member resolves to
    /// the connected user (mirrors Android's `CONNECTED_USER`).
    case connectedUser
    /// Another member: their posts-only screen. A member id is known (a synchronous profileId, or a
    /// clientUserId that resolved to someone other than the connected user) (mirrors Android's
    /// `OTHER_USER`).
    case resolved(profileId: String)
    /// A clientUserId entry point whose lookup did not resolve (unknown/stale mapping, network
    /// failure, or the community no longer exposing client user ids). The screen must show its empty
    /// state and never fall back to another member — the host asked for a specific one (mirrors
    /// Android's `CLIENT_LOOKUP_FAILED`).
    case lookupFailed
}

/// Whether the activity screen shows another member's posts rather than the connected user's own
/// activity. `true` only when a specific `requestedProfileId` was opened on demand and it differs from
/// the `connectedProfileId`. Pure so the self/other routing stays unit-testable independently of the
/// view-model wiring (mirrors Android's `isOtherUserActivity`).
///
/// - Parameters:
///   - requestedProfileId: the resolved Octopus id of the member that was requested, or `nil`.
///   - connectedProfileId: the connected user's own Octopus id, or `nil` (not connected / unknown).
func isOtherUserActivity(requestedProfileId: String?, connectedProfileId: String?) -> Bool {
    requestedProfileId != nil && requestedProfileId != connectedProfileId
}

/// Resolves the ``ActivityMode`` from the entry-point ids and the resolved target. Pure so the
/// connected / other / lookup-failed routing stays unit-testable independently of the view-model
/// wiring (mirrors Android's `resolveActivityMode`).
///
/// - Parameters:
///   - profileId: the synchronously-known Octopus profile id (the profileId entry point; Android's
///     `userId`), or `nil`.
///   - clientUserId: the host's own id (the clientUserId entry point), or `nil`.
///   - requestedUserId: the resolved Octopus id (`profileId`, or the clientUserId lookup result), or
///     `nil` when a clientUserId lookup did not resolve.
///   - connectedUserId: the connected user's own Octopus id, or `nil`.
/// - Returns: `.lookupFailed` for a clientUserId entry point that did not resolve; `.resolved` when a
///   resolved id differs from the connected user; `.connectedUser` when no id was requested or it
///   resolved to the connected user.
func resolveActivityMode(profileId: String?, clientUserId: String?,
                         requestedUserId: String?, connectedUserId: String?) -> ActivityMode {
    // A clientUserId entry point (no synchronous profileId) whose lookup did not resolve: the host
    // asked for a specific member, so never fall back to the connected user's own activity.
    if profileId == nil, clientUserId != nil, requestedUserId == nil {
        return .lookupFailed
    }
    // A resolved id that differs from the connected user → that member's posts-only screen.
    if isOtherUserActivity(requestedProfileId: requestedUserId, connectedProfileId: connectedUserId),
       let requestedUserId {
        return .resolved(profileId: requestedUserId)
    }
    // No id requested, or it resolved to the connected user → the connected user's own activity.
    return .connectedUser
}

/// View model of the "activity" screen (Unified Profile, OCT-1374). Polymorphic like Android's single
/// `ActivityScreen`:
/// - **connected-user mode** (``ActivityMode/connectedUser``): the connected user's own activity — the
///   two-tab "Activity" screen (Notifications + Posts) with the overflow menu. No profile header, no
///   gamification (that is exposed to the host via the read-only community-data API instead).
/// - **other-user mode** (``ActivityMode/resolved(profileId:)``): another member's posts-only screen,
///   under a "{nickname}'s Posts" title, no tabs, no overflow menu.
///
/// Three entry points (``ActivitySource``):
/// - `.connectedUser`: the home floating button — connected-user mode directly, no lookup.
/// - `.profileId`: a resolved Octopus id (in-community tap) — connected-user mode when it is the
///   connected user's own id, otherwise other-user mode.
/// - `.clientUserId`: the host's own id (`OctopusInitialScreen.activity`) — resolved once through
///   `fetchProfile(byClientUserId:)`, then routed like `.profileId`. A failed lookup never falls back
///   to any member (see ``resolveActivityMode``).
@MainActor
class ActivityViewModel: ObservableObject {
    // MARK: Other-user mode

    /// The member's nickname, used for the "{nickname}'s Posts" title (other-user mode). `nil` while
    /// the profile is still loading — the screen shows no title rather than an empty "'s Posts".
    @Published private(set) var nickname: String?
    @Published private(set) var error: DisplayableString?
    @Published private(set) var postFeedViewModel: PostFeedViewModel?

    /// The resolved Octopus profile id, published once known (synchronously in profileId mode; after
    /// the lookup settles in clientUserId mode). Drives the one-shot `otherUserPosts` screen event.
    /// `nil` while a clientUserId lookup is in flight, after it fails, or in connected-user mode.
    @Published private(set) var resolvedProfileId: String?

    /// `true` once a clientUserId lookup has failed — clears the preload loader and lets the screen
    /// render its empty state instead of spinning forever.
    @Published private(set) var lookupFailed = false

    // MARK: Connected-user mode

    /// `true` once the screen resolved to the connected user's own activity (see ``ActivityMode``).
    /// Drives the two-tab "Activity" chrome and the one-shot `profile` screen event.
    @Published private(set) var isConnectedUser = false
    /// The notifications feed of the connected user's own activity (connected-user mode only).
    @Published private(set) var notifCenterViewModel: NotificationCenterViewModel?
    /// `true` iff the connected user can create a post — gates the create-post incentive on the
    /// empty-posts placeholder. Defaults to `true` so behavior is preserved until permissions resolve.
    @Published private(set) var canCreatePost = true
    /// Whether the community allows poll creation (OCT-1426) — hides the poll incentive when off.
    @Published private(set) var pollsEnabled = true
    /// `true` when the connected user is a guest. Guests have no host profile, so the overflow menu's
    /// "View my profile" / "Edit my profile" actions are hidden (mirrors Android's `isGuest`).
    @Published private(set) var isGuest = false
    /// The connected user's own `clientUserId`, or `nil` (guest / not exposed) — gates the overflow
    /// menu's profile actions (Unified Profile needs a reachable host profile).
    @Published private(set) var connectedUserClientUserId: String?
    /// Whether the community exposes client user ids — the backend half of the Unified Profile gate,
    /// used by the overflow menu (see `unifiedProfileActive`).
    @Published private(set) var exposeClientUserId = false
    /// The tab the connected-user Activity screen lands on, published once connected-user mode is
    /// entered: the explicit `.connectedUser` tab (already resolved by
    /// `currentUserActivityDestination`), or the same unseen-notifications rule applied here when a
    /// profileId / clientUserId entry point resolves to the connected user (a self-tap). `nil` until
    /// connected-user mode is entered.
    @Published private(set) var connectedUserInitialTab: ActivityTab?

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    let octopus: OctopusSDK
    let source: ActivitySource
    let connectedActionChecker: ConnectedActionChecker

    private let translationStore: ContentTranslationPreferenceStore
    /// The resolved profile id used for cache tracking + refresh (other-user mode). Set synchronously
    /// (profileId mode) or after the lookup (clientUserId mode); `nil` until resolved / on lookup
    /// failure / in connected-user mode.
    private var profileId: String?
    /// `true` while the clientUserId lookup is in flight — `refresh()` is a no-op until it settles,
    /// so an early pull-to-refresh can't act before the target id is known (mirrors Android's
    /// `isResolvingByClientUserId`). Always `false` for the synchronous entry points.
    private var isResolvingByClientUserId: Bool
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, source: ActivitySource) {
        self.octopus = octopus
        self.source = source
        self.translationStore = translationStore
        self.connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        switch source {
        case let .profileId(profileId):
            // The id is known synchronously — resolve self vs. other against the connected user.
            self.isResolvingByClientUserId = false
            let connectedUserId = octopus.core.profileRepository.profile?.id
            switch resolveActivityMode(profileId: profileId, clientUserId: nil,
                                       requestedUserId: profileId, connectedUserId: connectedUserId) {
            case .connectedUser:
                enterConnectedUserMode()
            case let .resolved(resolvedId):
                startTracking(profileId: resolvedId)
                Task { await refreshProfile(manual: false) }
            case .lookupFailed:
                // Unreachable for a synchronous profileId (never nil), kept for exhaustiveness.
                lookupFailed = true
            }
        case let .clientUserId(clientUserId):
            // Self fast-path: when the requested client user id is the connected user's own (known
            // locally), enter connected-user mode synchronously — no network lookup, so the
            // "Activity" title and chrome are right from the very first frame. Without it, the
            // host-profile → "my community activity" entry point showed no title while the lookup
            // was in flight (PO feedback, 2026-07-17).
            if let connectedClientUserId = octopus.core.profileRepository.profile?.clientUserId,
               connectedClientUserId == clientUserId {
                self.isResolvingByClientUserId = false
                enterConnectedUserMode()
            } else {
                // The id is unknown until the async lookup resolves it — gate refresh() until then.
                self.isResolvingByClientUserId = true
                Task { await resolveClientUserIdThenTrack() }
            }
        case .connectedUser:
            // The connected user's own activity, opened directly by the floating button.
            self.isResolvingByClientUserId = false
            enterConnectedUserMode()
        }
    }

    func refresh() async {
        if isConnectedUser {
            await refreshConnectedUser(manual: true)
            return
        }
        // No-op while the clientUserId lookup is still resolving: the target id is unknown, and we
        // must not fall through to refreshing anyone else (mirrors Android's isResolvingByClientUserId
        // guard).
        guard !isResolvingByClientUserId else { return }
        // Lookup failed (no resolved member) — nothing to refresh.
        guard profileId != nil else { return }
        // If the profile refresh failed, do not refresh the feed (avoids two error alerts).
        if await refreshProfile(manual: true) {
            await postFeedViewModel?.refresh()
        }
    }

    func ensureConnected(action: UserAction) -> Bool {
        connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    // MARK: - Other-user mode

    /// Subscribes to the cached profile for `profileId` and builds the posts feed — the machinery the
    /// other-user entry points converge on once a member id is known.
    private func startTracking(profileId: String) {
        self.profileId = profileId
        self.resolvedProfileId = profileId

        octopus.core.profileRepository.getProfile(profileId: profileId)
            .removeDuplicates()
            .sink { [unowned self] profile in
                self.nickname = profile?.nickname
                if let newestFirstPostsFeed = profile?.newestFirstPostsFeed {
                    // Update the view model only if feed id has changed
                    if postFeedViewModel?.feed.id != newestFirstPostsFeed.id {
                        postFeedViewModel = PostFeedViewModel(
                            octopus: octopus, postFeed: newestFirstPostsFeed,
                            translationStore: translationStore,
                            ensureConnected: { [weak self] action in
                                guard let self else { return false }
                                return self.ensureConnected(action: action)
                            })
                    }
                } else {
                    postFeedViewModel = nil
                }
            }.store(in: &storage)
    }

    /// Resolves the clientUserId entry point to an Octopus id, then routes to the matching mode —
    /// connected-user, another member, or the empty lookup-failed state (never falling back to anyone).
    private func resolveClientUserIdThenTrack() async {
        guard case let .clientUserId(clientUserId) = source else { return }
        let requestedUserId = await resolveProfile(byClientUserId: clientUserId)
        // The async lookup has settled — let refresh() run again.
        isResolvingByClientUserId = false
        let connectedUserId = octopus.core.profileRepository.profile?.id
        switch resolveActivityMode(profileId: nil, clientUserId: clientUserId,
                                   requestedUserId: requestedUserId, connectedUserId: connectedUserId) {
        case .connectedUser:
            enterConnectedUserMode()
        case let .resolved(profileId):
            startTracking(profileId: profileId)
        case .lookupFailed:
            // Stop the preload loader so it doesn't spin forever; the screen shows its empty state.
            lookupFailed = true
        }
    }

    /// Resolves the member behind `clientUserId` to its Octopus profile id, surfacing lookup errors
    /// the same way `refreshProfile(manual: false)` does. Returns `nil` on an unknown member (empty
    /// response) or any failure (e.g. no network, or a server error when the community does not
    /// expose client user ids).
    private func resolveProfile(byClientUserId clientUserId: String) async -> String? {
        do {
            return try await octopus.core.profileRepository.fetchProfile(byClientUserId: clientUserId)?.id
        } catch {
            if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            }
            return nil
        }
    }

    /// Refresh the (other-user) profile.
    /// - Parameter manual: whether the refresh is a manual (pull-to-refresh) one.
    /// - Returns: `true` if the refresh succeeded, `false` otherwise.
    @discardableResult
    private func refreshProfile(manual: Bool) async -> Bool {
        guard let profileId else { return false }
        do {
            try await octopus.core.profileRepository.fetchProfile(profileId: profileId)
        } catch {
            if manual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            }
            return false
        }
        return true
    }

    // MARK: - Connected-user mode

    /// Wires the connected user's own activity: the notifications feed and the posts feed, plus the
    /// signals the overflow menu needs (guest, client id, exposeClientUserId) and the create-post
    /// gating. Reuses the same machinery as `CurrentUserProfileSummaryViewModel` but without the
    /// profile header / gamification (mirrors Android's connected-user `ActivityScreen`).
    private func enterConnectedUserMode() {
        guard !isConnectedUser else { return }
        isConnectedUser = true
        // Landing tab: the floating button already resolved it (`currentUserActivityDestination`);
        // the other entry points (self-tap resolving to the connected user) apply the same
        // unseen-notifications rule here.
        if case let .connectedUser(initialTab) = source {
            connectedUserInitialTab = initialTab
        } else {
            let hasUnseenNotifications = (octopus.core.profileRepository.profile?.notificationBadgeCount ?? 0) > 0
            connectedUserInitialTab = hasUnseenNotifications ? .notifications : .posts
        }
        notifCenterViewModel = NotificationCenterViewModel(octopus: octopus)

        octopus.core.profileRepository.profilePublisher
            .removeDuplicates()
            .sink { [unowned self] profile in
                guard let profile else { return }
                isGuest = profile.isGuest
                connectedUserClientUserId = profile.clientUserId
                let newestFirstPostsFeed = profile.newestFirstPostsFeed
                // Update the view model only if feed id has changed
                if postFeedViewModel?.feed.id != newestFirstPostsFeed.id {
                    postFeedViewModel = PostFeedViewModel(
                        octopus: octopus, postFeed: newestFirstPostsFeed,
                        displayModeratedPosts: true,
                        translationStore: translationStore,
                        ensureConnected: { _ in true })
                }
            }.store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { ($0?.contentOptions ?? .allEnabled).post.enablePolls }
            .removeDuplicates()
            .sink { [unowned self] in pollsEnabled = $0 }
            .store(in: &storage)

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.exposeClientUserId ?? false }
            .removeDuplicates()
            .sink { [unowned self] in exposeClientUserId = $0 }
            .store(in: &storage)

        octopus.core.topicsRepository.$canCreateAnyPost
            .removeDuplicates()
            .sink { [unowned self] in canCreatePost = $0 }
            .store(in: &storage)

        octopus.core.sdkEventsEmitter.internalEvents
            .sink { [unowned self] internalEvent in
                switch internalEvent {
                case .contentCreated, .contentDeleted, .contentReactionChanged:
                    Task { await refreshConnectedUser(manual: false) }
                default: break
                }
            }.store(in: &storage)

        Task { await refreshConnectedUser(manual: false) }
    }

    /// Refresh the connected user's profile (posts feed) and notifications together.
    private func refreshConnectedUser(manual: Bool) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                if await refreshCurrentUserProfile(manual: manual) {
                    await postFeedViewModel?.refresh()
                }
            }
            group.addTask { [self] in await refreshNotifCenter() }
            await group.waitForAll()
        }
    }

    @discardableResult
    private func refreshCurrentUserProfile(manual: Bool) async -> Bool {
        do {
            try await octopus.core.profileRepository.fetchCurrentUserProfile()
        } catch {
            if manual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            }
            return false
        }
        return true
    }

    private func refreshNotifCenter() async {
        do {
            try await notifCenterViewModel?.refresh()
        } catch {
            self.error = error.displayableMessage
        }
    }
}
