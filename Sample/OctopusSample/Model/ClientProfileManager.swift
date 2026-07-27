//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// Singleton that bridges the SDK's `onNavigateToProfileCallback` to a published property that
/// views can observe, and lets the sample wire/unwire that callback live (Unified Profile,
/// OCT-1374).
///
/// The callback is one of the two inputs of the Unified Profile AND-gate (the other being
/// `CommunityConfig.exposeClientUserId`). iOS reads `onNavigateToProfileCallback` at every profile
/// tap, so toggling it takes effect immediately — no SDK restart needed (unlike Android, whose
/// wiring is captured when the nav graph is built).
class ClientProfileManager: ObservableObject {
    static let instance = ClientProfileManager()

    /// The `clientUserId` of the most recently tapped member, published as a one-shot event: the
    /// observer captures it and resets it to `nil` immediately on consume (see `OctopusUIView`), so
    /// it is only ever transiently non-nil. That prevents `@Published` from replaying a stale value
    /// to a later subscriber (e.g. the "See their Octopus posts" activity screen, itself an
    /// `OctopusUIView`), which would otherwise re-fire the presentation and cancel that sheet.
    @Published var tappedClientUserId: String?

    /// Whether `onNavigateToProfileCallback` is currently wired on the SDK — the host-side half of
    /// the Unified Profile AND-gate. Toggle it from the Unified Profile scenario to exercise the
    /// "callback unwired → SDK keeps its native profile screens" path. Wired by default.
    @Published private(set) var isCallbackWired: Bool = true

    /// One-shot event fired when the SDK invokes `onNavigateToProfileEditCallback` — the "Edit my
    /// profile" item of the connected-user Activity screen's top-right menu (Unified Profile,
    /// OCT-1374). The observer sets it back to `false` immediately on consume (see `OctopusUIView`),
    /// mirroring `tappedClientUserId`'s one-shot pattern.
    @Published var editProfileRequested: Bool = false

    /// Whether `onNavigateToProfileEditCallback` is currently wired on the SDK. Independent of
    /// `isCallbackWired`: the Activity menu shows "Edit my profile" only when this is wired, so the
    /// scenario can exercise both the wired (item shown → host edit screen) and unwired (item hidden)
    /// paths. Wired by default.
    @Published private(set) var isEditCallbackWired: Bool = true

    private weak var octopus: OctopusSDK?

    private init() { }

    /// Function called when the Octopus SDK is created. Stores the instance and (re)applies the
    /// current wiring state to it.
    func set(octopus: OctopusSDK) {
        self.octopus = octopus
        applyWiring()
    }

    /// Wire or unwire `onNavigateToProfileCallback` on the current SDK instance. Takes effect on the
    /// next profile tap.
    func setCallbackWired(_ wired: Bool) {
        isCallbackWired = wired
        applyWiring()
    }

    /// Wire or unwire `onNavigateToProfileEditCallback` on the current SDK instance. Takes effect the
    /// next time the connected-user Activity menu is opened.
    func setEditCallbackWired(_ wired: Bool) {
        isEditCallbackWired = wired
        applyWiring()
    }

    private func applyWiring() {
        octopus?.set(onNavigateToProfileCallback: isCallbackWired ? { [weak self] clientUserId in
            /// Block invoked by the SDK when the user taps a profile inside the community (another
            /// member's or their own) while Unified Profile is active (this callback wired + the
            /// community exposes client user ids). The host app decides what to do with the
            /// `clientUserId`. In this sample we surface the host's own stand-in profile screen.
            self?.tappedClientUserId = clientUserId
        } : nil)

        octopus?.set(onNavigateToProfileEditCallback: isEditCallbackWired ? { [weak self] _ in
            /// Block invoked by the SDK when the connected user taps "Edit my profile" in the Activity
            /// screen's top-right menu. The host app opens its own edit screen for the requested field
            /// (nil = the whole profile). In this sample we reuse the host's `AppEditUserScreen`; the
            /// `fieldToEdit` is ignored because that screen edits the whole profile.
            self?.editProfileRequested = true
        } : nil)
    }
}
