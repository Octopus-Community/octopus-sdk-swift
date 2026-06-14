//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// A leading navigation-bar item driven by the host app, displayed on whatever Octopus screen is at the
/// root of the Octopus navigation stack (the screen selected via `OctopusHomeScreen`'s `initialScreen`:
/// the main feed, or a bridge post / group, …).
///
/// Use this when you host `OctopusHomeScreen` somewhere the SDK has no SwiftUI presentation context to
/// dismiss — e.g. pushed onto your own `UINavigationController` stack, or mounted by a Flutter / React
/// Native plugin inside a `UIHostingController`. In those setups the SDK's built-in close button never
/// appears (it only shows when the view is presented natively via `.sheet` / `.fullScreenCover`), so the
/// host needs to provide its own dismiss affordance and be told when it is tapped.
///
/// The tap fires the closure you provide instead of dismissing a SwiftUI presentation — it is up to the
/// host to pop its route / dismiss its container.
public enum OctopusNavBarLeadingAction {
    /// A close button (the SDK's "close" icon), e.g. for a modally-presented host container.
    case close(onTap: () -> Void)
    /// A back button (a back chevron), e.g. for a host navigation route.
    case back(onTap: () -> Void)

    /// The closure to run when the item is tapped.
    var onTap: () -> Void {
        switch self {
        case let .close(onTap): return onTap
        case let .back(onTap): return onTap
        }
    }
}
