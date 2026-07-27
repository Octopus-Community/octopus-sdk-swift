//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

final class SlideUpFromBottomAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    enum Direction {
        case present
        case dismiss
    }

    let direction: Direction
    // Mirror the iOS system modal (fullScreenCover) presentation: a near-critically-damped spring
    // that decelerates smoothly at the end without bouncing.
    private let duration: TimeInterval = 0.5
    private let springDamping: CGFloat = 0.9

    init(direction: Direction) {
        self.direction = direction
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        switch direction {
        case .present:
            guard let toVC = transitionContext.viewController(forKey: .to),
                  let toView = transitionContext.view(forKey: .to) else {
                transitionContext.completeTransition(false)
                return
            }
            let finalFrame = transitionContext.finalFrame(for: toVC)
            toView.frame = finalFrame.offsetBy(dx: 0, dy: container.bounds.height)
            container.addSubview(toView)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: springDamping,
                initialSpringVelocity: 0,
                options: [],
                animations: { toView.frame = finalFrame },
                completion: { _ in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        case .dismiss:
            guard let toVC = transitionContext.viewController(forKey: .to),
                  let toView = transitionContext.view(forKey: .to),
                  let fromView = transitionContext.view(forKey: .from) else {
                transitionContext.completeTransition(false)
                return
            }
            toView.frame = transitionContext.finalFrame(for: toVC)
            container.insertSubview(toView, belowSubview: fromView)
            let initialFrame = fromView.frame
            UIView.animate(
                withDuration: duration,
                delay: 0,
                usingSpringWithDamping: springDamping,
                initialSpringVelocity: 0,
                options: [],
                animations: { fromView.frame = initialFrame.offsetBy(dx: 0, dy: container.bounds.height) },
                completion: { _ in
                    fromView.removeFromSuperview()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        }
    }
}
