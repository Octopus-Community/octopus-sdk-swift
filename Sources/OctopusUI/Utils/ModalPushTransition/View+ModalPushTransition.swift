//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Installs `OctopusNavTransitionProxy` on the nearest ancestor `UINavigationController`.
    /// The proxy uses `shouldUseModalTransition` (called synchronously when the nav controller
    /// asks for a push animator) to decide whether to slide a destination up from the bottom.
    /// Matching pops are detected automatically by tracking the pushed controller.
    func installOctopusNavTransitionProxy(
        shouldUseModalTransition: @escaping OctopusNavTransitionProxy.Decision
    ) -> some View {
        background(
            NavTransitionProxyInstaller(decision: shouldUseModalTransition)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

private struct NavTransitionProxyInstaller: UIViewControllerRepresentable {
    let decision: OctopusNavTransitionProxy.Decision

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let decision = self.decision
        DispatchQueue.main.async {
            // We are on the main queue, so the main actor is active: `assumeIsolated` lets us reach
            // the `@MainActor` proxy state without changing the (timing-sensitive) dispatch.
            MainActor.assumeIsolated {
                var current: UIViewController? = uiViewController.parent
                while let candidate = current {
                    if let nav = candidate.navigationController {
                        install(on: nav, decision: decision, retainedBy: context.coordinator)
                        return
                    }
                    current = candidate.parent
                }
            }
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        // If the installer view disappears while its navigation controller survives, hand the
        // delegate back to SwiftUI instead of leaving the soon-to-be-released proxy in place.
        guard let nav = coordinator.installedNav else { return }
        coordinator.retainedProxy?.detachIfInstalled(from: nav)
    }

    @MainActor
    private func install(
        on nav: UINavigationController,
        decision: @escaping OctopusNavTransitionProxy.Decision,
        retainedBy coordinator: Coordinator
    ) {
        coordinator.installedNav = nav
        if let existing = nav.delegate as? OctopusNavTransitionProxy {
            existing.shouldUseModalTransition = decision
            existing.navigationController = nav
            coordinator.retainedProxy = existing
            return
        }
        let proxy = OctopusNavTransitionProxy()
        // `previousDelegate` is weak: a working UINavigationControllerDelegate is necessarily retained
        // by its real owner (the weak `nav.delegate` slot alone could never keep it alive), so SwiftUI's
        // delegate stays valid here for as long as it is in use. This is the conventional forwarding-proxy
        // ownership model and has been validated on iOS 16/17/26 in both modal and embedded presentations.
        proxy.previousDelegate = nav.delegate
        proxy.shouldUseModalTransition = decision
        proxy.navigationController = nav
        nav.delegate = proxy
        // Providing a custom `animationControllerFor` makes UIKit disable the interactive edge-swipe
        // "back" gesture. Own its delegate so we can re-allow it for standard pushes (see the proxy's
        // `gestureRecognizerShouldBegin`) — restoring the native back gesture that regressed in 1.13.
        if let popGesture = nav.interactivePopGestureRecognizer {
            proxy.previousPopGestureDelegate = popGesture.delegate
            popGesture.delegate = proxy
        }
        coordinator.retainedProxy = proxy
    }

    final class Coordinator {
        var retainedProxy: OctopusNavTransitionProxy?
        weak var installedNav: UINavigationController?
    }
}
