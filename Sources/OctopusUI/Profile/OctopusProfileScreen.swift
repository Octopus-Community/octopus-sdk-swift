//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// UI Entry point to open an Octopus profile directly.
///
/// Deprecated: open `OctopusHomeScreen` with the `.profile` initial screen and `navigationMode: .navigationStack`
/// instead, which displays the same profile and, like every initial screen, the access denied screen when the user
/// cannot access the community. This view now displays exactly that.
///
/// This SwiftUI view contains a NavigationView, hence it should be not embedded in another Navigation object.
@available(*, deprecated,
            message: "Use OctopusHomeScreen(octopus:initialScreen: .profile(...), navigationMode: .navigationStack).")
public struct OctopusProfileScreen: View {

    private let octopus: OctopusSDK
    private let clientUserId: String?
    private let navigationMode: OctopusNavigationMode
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    /// Constructor of the `OctopusProfileScreen`.
    /// - Parameters:
    ///    - octopus: The Octopus SDK
    ///    - clientUserId: the host app's own id (as passed to `ConnectionMode.sso`) for the member whose
    ///                    profile to display. Default is `nil`, which displays the connected user's own
    ///                    profile. When set, the profile is resolved via the community's dedicated
    ///                    clientUserId lookup; if it cannot be resolved (unknown id, the community does not
    ///                    expose client user ids, or a network failure), an error state is shown —
    ///                    the screen never falls back to displaying the connected user's own profile.
    ///    - navigationMode: which navigation container the screen uses internally. Default is
    ///                      `.navigationStack`, which suits the modal presentation (`.fullScreenCover`) this
    ///                      screen was made for: there, the legacy `NavigationView` behind `.automatic` can
    ///                      silently drop in-app pushes. See `OctopusNavigationMode`.
    ///    - navBarLeadingAction: an optional host-driven leading nav-bar item displayed on the profile screen.
    ///                           Use it when you host `OctopusProfileScreen` somewhere the SDK cannot dismiss
    ///                           itself (pushed on your own navigation stack, or mounted by a Flutter / React
    ///                           Native plugin): the SDK's built-in close button only appears when the view is
    ///                           presented natively (`.sheet` / `.fullScreenCover`). Pass `.close(onTap:)` or
    ///                           `.back(onTap:)` to show the corresponding item and be told when it is tapped —
    ///                           the closure runs instead of dismissing a SwiftUI presentation. Default is nil.
    ///
    /// You can pass an OctopusTheme as an environment to customize the colors, fonts and images used in this
    /// view:
    /// ```swift
    /// OctopusProfileScreen(octopus: octopus)
    ///     .environment(\.octopusTheme, appTheme)
    /// ```
    public init(octopus: OctopusSDK, clientUserId: String? = nil,
                navigationMode: OctopusNavigationMode = .navigationStack,
                navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        self.octopus = octopus
        self.clientUserId = clientUserId
        self.navigationMode = navigationMode
        self.navBarLeadingAction = navBarLeadingAction
    }

    public var body: some View {
        OctopusHomeScreen(octopus: octopus,
                          initialScreen: profileInitialScreen(clientUserId: clientUserId),
                          navigationMode: navigationMode,
                          navBarLeadingAction: navBarLeadingAction)
    }
}

/// The initial screen that displays what `OctopusProfileScreen` displays for a client user id.
/// - Parameter clientUserId: the host app's own id for the member, `nil` for the connected user's own profile
func profileInitialScreen(clientUserId: String?) -> OctopusInitialScreen {
    .profile(clientUserId.map { .init(clientUserId: $0) } ?? .currentUser)
}
