//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// `UINavigationControllerDelegate` proxy that returns a slide-up animator whenever
/// `shouldUseModalTransition` returns `true` for a push. The pushed controller is
/// remembered so the matching pop also gets a slide-down animator. All other delegate
/// methods are forwarded to `previousDelegate` so SwiftUI's `NavigationView` plumbing
/// keeps working untouched.
///
/// The type is `@MainActor`: UIKit only invokes navigation-controller delegate methods on the
/// main thread, and the proxy is only ever installed from the main queue (see
/// `View+ModalPushTransition`). That lets `shouldUseModalTransition` and `modalTransitionVCs`
/// be regular, compiler-checked main-actor state.
///
/// The single exception is `previousDelegate`: the Objective-C message-forwarding runtime reaches
/// it through `responds(to:)` / `forwardingTarget(for:)`, which must stay `nonisolated` to override
/// their `NSObject` counterparts — so the stored property cannot be main-actor-isolated and is kept
/// `nonisolated(unsafe)`. In practice every access still happens on the main thread.
@MainActor
final class OctopusNavTransitionProxy: NSObject, UINavigationControllerDelegate {
    typealias Decision = (UINavigationController.Operation, UIViewController, UIViewController) -> Bool

    nonisolated(unsafe) weak var previousDelegate: UINavigationControllerDelegate?
    var shouldUseModalTransition: Decision = { _, _, _ in false }

    /// The navigation controller this proxy is installed on. Used by the interactive-pop gesture
    /// delegate to check the stack depth. Weak: the nav controller owns the gesture, not us.
    weak var navigationController: UINavigationController?

    /// The delegate that owned `interactivePopGestureRecognizer` before we took it over, restored on
    /// detach so we don't leave the gesture pointing at our (about-to-be-released) proxy.
    weak var previousPopGestureDelegate: UIGestureRecognizerDelegate?

    private var modalTransitionVCs: Set<ObjectIdentifier> = []

    override nonisolated func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        return previousDelegate?.responds(to: aSelector) ?? false
    }

    override nonisolated func forwardingTarget(for aSelector: Selector!) -> Any? {
        if previousDelegate?.responds(to: aSelector) == true {
            return previousDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push where shouldUseModalTransition(.push, fromVC, toVC):
            modalTransitionVCs.insert(ObjectIdentifier(toVC))
            return SlideUpFromBottomAnimator(direction: .present)
        case .pop where modalTransitionVCs.remove(ObjectIdentifier(fromVC)) != nil:
            return SlideUpFromBottomAnimator(direction: .dismiss)
        default:
            return previousDelegate?.navigationController?(
                navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
        }
    }

    /// Restores `previousDelegate` on `nav` if (and only if) this proxy is still its delegate.
    /// Called on teardown so a navigation controller that outlives the installer view isn't left
    /// with our (about-to-be-deallocated) proxy — which `nav.delegate`'s weak slot would otherwise
    /// turn into `nil`, silently dropping SwiftUI's own navigation delegate callbacks.
    func detachIfInstalled(from nav: UINavigationController) {
        guard nav.delegate === self else { return }
        nav.delegate = previousDelegate
        if nav.interactivePopGestureRecognizer?.delegate === self {
            nav.interactivePopGestureRecognizer?.delegate = previousPopGestureDelegate
        }
    }
}

extension OctopusNavTransitionProxy: UIGestureRecognizerDelegate {
    /// Restores the native edge-swipe "back" gesture. UIKit disables `interactivePopGestureRecognizer`
    /// as soon as the navigation controller's delegate provides custom transition animators
    /// (`animationControllerFor`) — which regressed the swipe-back in 1.13. We own the gesture's
    /// delegate and allow it to begin whenever there is something to pop, except on the modal slide-up
    /// push, which manages its own dismissal (matching the pre-1.13 `.sheet` behavior).
    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated {
            guard let nav = navigationController, nav.viewControllers.count > 1 else { return false }
            if let top = nav.topViewController, modalTransitionVCs.contains(ObjectIdentifier(top)) {
                return false
            }
            return true
        }
    }
}
