//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusUI

@Suite
@MainActor
class OctopusNavTransitionProxyTests {

    // MARK: - Push

    @Test func push_whenDecisionReturnsTrue_returnsSlideUpPresentAnimator() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { operation, _, _ in operation == .push }

        let animator = proxy.navigationController(
            UINavigationController(), animationControllerFor: .push,
            from: UIViewController(), to: UIViewController())

        let slide = animator as? SlideUpFromBottomAnimator
        #expect(slide != nil)
        #expect(slide?.direction == .present)
    }

    @Test func push_whenDecisionReturnsFalse_withoutPreviousDelegate_returnsNil() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { _, _, _ in false }

        let animator = proxy.navigationController(
            UINavigationController(), animationControllerFor: .push,
            from: UIViewController(), to: UIViewController())

        #expect(animator == nil)
    }

    @Test func push_whenDecisionReturnsFalse_forwardsToPreviousDelegate() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { _, _, _ in false }
        let previous = StubNavDelegate()
        proxy.previousDelegate = previous

        let animator = proxy.navigationController(
            UINavigationController(), animationControllerFor: .push,
            from: UIViewController(), to: UIViewController())

        #expect(previous.animationControllerCallCount == 1)
        #expect(animator === previous.stubAnimator)
    }

    // MARK: - Pop

    @Test func pop_ofPreviouslyModallyPushedController_returnsSlideUpDismissAnimator() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { operation, _, _ in operation == .push }
        let nav = UINavigationController()
        let rootVC = UIViewController()
        let modalVC = UIViewController()

        // Push the destination so the proxy starts tracking it as a modal transition.
        _ = proxy.navigationController(nav, animationControllerFor: .push, from: rootVC, to: modalVC)
        // Popping that same controller must produce the matching slide-down animator.
        let animator = proxy.navigationController(nav, animationControllerFor: .pop, from: modalVC, to: rootVC)

        let slide = animator as? SlideUpFromBottomAnimator
        #expect(slide != nil)
        #expect(slide?.direction == .dismiss)
    }

    @Test func pop_ofUntrackedController_withoutPreviousDelegate_returnsNil() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { _, _, _ in true }

        let animator = proxy.navigationController(
            UINavigationController(), animationControllerFor: .pop,
            from: UIViewController(), to: UIViewController())

        #expect(animator == nil)
    }

    @Test func pop_isMatchedOnlyOnce_secondPopOfSameControllerForwards() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { operation, _, _ in operation == .push }
        let nav = UINavigationController()
        let modalVC = UIViewController()

        _ = proxy.navigationController(nav, animationControllerFor: .push,
                                       from: UIViewController(), to: modalVC)
        _ = proxy.navigationController(nav, animationControllerFor: .pop,
                                       from: modalVC, to: UIViewController())
        // The tracked controller has been consumed; a second pop is no longer a modal transition.
        let second = proxy.navigationController(nav, animationControllerFor: .pop,
                                                from: modalVC, to: UIViewController())

        #expect(second == nil)
    }

    // MARK: - Interactive pop gesture (native swipe-back)

    @Test func gestureShouldBegin_isFalse_withoutNavigationController() {
        let proxy = OctopusNavTransitionProxy()
        #expect(!proxy.gestureRecognizerShouldBegin(UIScreenEdgePanGestureRecognizer()))
    }

    @Test func gestureShouldBegin_isFalse_whenStackHasSingleController() {
        let proxy = OctopusNavTransitionProxy()
        let nav = UINavigationController(rootViewController: UIViewController())
        proxy.navigationController = nav

        #expect(!proxy.gestureRecognizerShouldBegin(UIScreenEdgePanGestureRecognizer()))
    }

    @Test func gestureShouldBegin_isTrue_forStandardPush() {
        let proxy = OctopusNavTransitionProxy()
        let nav = UINavigationController()
        nav.viewControllers = [UIViewController(), UIViewController()]
        proxy.navigationController = nav

        #expect(proxy.gestureRecognizerShouldBegin(UIScreenEdgePanGestureRecognizer()))
    }

    @Test func gestureShouldBegin_isFalse_whenTopControllerIsModalSlideUp() {
        let proxy = OctopusNavTransitionProxy()
        proxy.shouldUseModalTransition = { operation, _, _ in operation == .push }
        let nav = UINavigationController()
        let root = UIViewController()
        let modalVC = UIViewController()
        // Track modalVC as a modal-transition push so the proxy knows the top screen manages its own dismissal.
        _ = proxy.navigationController(nav, animationControllerFor: .push, from: root, to: modalVC)
        nav.viewControllers = [root, modalVC]
        proxy.navigationController = nav

        #expect(!proxy.gestureRecognizerShouldBegin(UIScreenEdgePanGestureRecognizer()))
    }

    // MARK: - Teardown

    @Test func detachIfInstalled_restoresPreviousDelegate_whenProxyIsTheCurrentDelegate() {
        let nav = UINavigationController()
        let original = StubNavDelegate()
        nav.delegate = original
        let proxy = OctopusNavTransitionProxy()
        proxy.previousDelegate = nav.delegate
        nav.delegate = proxy

        proxy.detachIfInstalled(from: nav)

        #expect(nav.delegate === original)
    }

    @Test func detachIfInstalled_leavesDelegateUntouched_whenProxyIsNotTheCurrentDelegate() {
        let nav = UINavigationController()
        let other = StubNavDelegate()
        nav.delegate = other
        let proxy = OctopusNavTransitionProxy()

        proxy.detachIfInstalled(from: nav)

        #expect(nav.delegate === other)
    }

    // MARK: - Transparent delegate forwarding

    @Test func respondsToSelector_isTrue_forSelectorImplementedOnlyByPreviousDelegate() {
        let proxy = OctopusNavTransitionProxy()
        // `previousDelegate` is weak, so the stub must be retained locally for the duration of the test.
        let previous = StubNavDelegate()
        proxy.previousDelegate = previous

        let didShow = #selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:))
        #expect(proxy.responds(to: didShow))
    }

    @Test func respondsToSelector_isFalse_whenNeitherProxyNorPreviousDelegateImplementsIt() {
        let proxy = OctopusNavTransitionProxy()

        let didShow = #selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:))
        #expect(!proxy.responds(to: didShow))
    }

    @Test func forwardingTarget_returnsPreviousDelegate_forSelectorItImplements() {
        let proxy = OctopusNavTransitionProxy()
        let previous = StubNavDelegate()
        proxy.previousDelegate = previous

        let didShow = #selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:))
        #expect(proxy.forwardingTarget(for: didShow) as? StubNavDelegate === previous)
    }
}

// MARK: - Test doubles

@MainActor
private final class StubNavDelegate: NSObject, UINavigationControllerDelegate {
    let stubAnimator = StubAnimator()
    private(set) var animationControllerCallCount = 0

    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        animationControllerCallCount += 1
        return stubAnimator
    }

    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController, animated: Bool) {
        // Implemented only so the proxy has a selector to forward; behavior is irrelevant here.
    }
}

@MainActor
private final class StubAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0 }
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) { }
}
