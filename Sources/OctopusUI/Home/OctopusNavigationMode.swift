//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Controls which navigation container `OctopusHomeScreen` uses internally.
///
/// `OctopusHomeScreen` drives its sub-navigation (opening a post, a group, a profile, …) through a
/// navigation path. The container backing that path can either be the legacy `NavigationView` or a
/// `NavigationStack`. They don't behave identically when the screen is hosted inside a **modal
/// presentation**: see ``automatic`` and ``navigationStack`` for details.
public enum OctopusNavigationMode {
    /// The SDK picks the navigation container. It currently uses a legacy `NavigationView` (chosen to
    /// work around an internal `CreatePostView` lifecycle issue); this default may change in a future
    /// version.
    ///
    /// ⚠️ Known limitation: when `OctopusHomeScreen` is hosted inside a **modal presentation** that
    /// reparents its hosting controller (SwiftUI `.sheet` / `.fullScreenCover`, or a Flutter / React
    /// Native modal route), the legacy `NavigationView` can silently drop programmatic pushes — e.g.
    /// tapping a post no longer opens its detail. In that hosting context, use ``navigationStack``.
    case automatic

    /// Forces a `NavigationStack` when available (iOS 16+, with a legacy `NavigationView` fallback below
    /// iOS 16). `NavigationStack` keeps its navigation path working across hosting-controller
    /// reparenting, so this is the recommended mode when hosting `OctopusHomeScreen` inside a modal
    /// presentation (`.sheet` / `.fullScreenCover`, Flutter / React Native modal route, …).
    case navigationStack
}
