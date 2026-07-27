//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Forces a fully opaque navigation bar (a solid background that also covers the status bar
    /// area) for the screen this is attached to, restoring the previous appearance when the
    /// screen disappears.
    ///
    /// SwiftUI's `.toolbarBackground` does not reliably defeat the iOS 26 glass navigation bar,
    /// so dark content (e.g. a video) scrolling under the bar makes the title and the status bar
    /// flip to white. Configuring an opaque `UINavigationBarAppearance` is the reliable,
    /// cross-version way to keep the bar — and the status bar over it — stable. The background
    /// uses `systemBackground`, so it adapts to light/dark mode automatically.
    @ViewBuilder
    func opaqueNavigationBar(_ enabled: Bool, color: UIColor = .systemBackground) -> some View {
        if enabled {
            background(OpaqueNavBarConfigurator(backgroundColor: color))
        } else {
            self
        }
    }
}

private struct OpaqueNavBarConfigurator: UIViewControllerRepresentable {
    let backgroundColor: UIColor

    func makeUIViewController(context: Context) -> Controller {
        Controller(backgroundColor: backgroundColor)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        // Only react to an actual color change. Re-applying on every SwiftUI re-render (frequent
        // during scroll, as `isScrollingDown` toggles) triggers a nav-bar appearance transition
        // that briefly dims the bar items (title disappears, buttons go gray).
        controller.update(backgroundColor: backgroundColor)
    }

    /// Invisible controller used only to reach the hosting `UINavigationController` and force its
    /// navigation bar appearance opaque while this screen is on screen.
    final class Controller: UIViewController {
        private(set) var backgroundColor: UIColor

        private var savedStandard: UINavigationBarAppearance?
        private var savedScrollEdge: UINavigationBarAppearance?
        private var savedCompact: UINavigationBarAppearance?
        private var didSave = false
        /// The color currently applied to the bar; `nil` means "needs (re)apply".
        private var appliedColor: UIColor?

        init(backgroundColor: UIColor) {
            self.backgroundColor = backgroundColor
            super.init(nibName: nil, bundle: nil)
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        func update(backgroundColor: UIColor) {
            guard self.backgroundColor != backgroundColor else { return }
            self.backgroundColor = backgroundColor
            appliedColor = nil
            applyOpaqueAppearance()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Force a re-apply: another screen may have changed the shared bar while we were away.
            appliedColor = nil
            applyOpaqueAppearance()
        }

        // The hosting `UINavigationController` is not always attached by `viewWillAppear`
        // (e.g. inside a modally-presented `NavigationStack`), so re-apply once laid out.
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyOpaqueAppearance()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restoreAppearance()
        }

        func applyOpaqueAppearance() {
            guard appliedColor != backgroundColor, let bar = resolvedNavigationBar() else { return }
            if !didSave {
                savedStandard = bar.standardAppearance
                savedScrollEdge = bar.scrollEdgeAppearance
                savedCompact = bar.compactAppearance
                didSave = true
            }
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            // Preserve any title styling the host app / SDK configured.
            appearance.titleTextAttributes = bar.standardAppearance.titleTextAttributes
            appearance.largeTitleTextAttributes = bar.standardAppearance.largeTitleTextAttributes
            bar.standardAppearance = appearance
            bar.scrollEdgeAppearance = appearance
            bar.compactAppearance = appearance
            appliedColor = backgroundColor
        }

        private func restoreAppearance() {
            appliedColor = nil
            guard didSave, let bar = resolvedNavigationBar() else { return }
            if let savedStandard { bar.standardAppearance = savedStandard }
            bar.scrollEdgeAppearance = savedScrollEdge
            bar.compactAppearance = savedCompact
        }

        /// Walk up the controller hierarchy to find the enclosing navigation bar.
        private func resolvedNavigationBar() -> UINavigationBar? {
            var controller: UIViewController? = self
            while let current = controller {
                if let navBar = current.navigationController?.navigationBar {
                    return navBar
                }
                controller = current.parent
            }
            return nil
        }
    }
}
