//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

class ModalHostingController<Content: View>: UIHostingController<Content>, UIAdaptivePresentationControllerDelegate {
    var canDismissSheet = true
    var onDismissalAttempt: (() -> ())?

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)

        parent?.presentationController?.delegate = self
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        if !canDismissSheet {
            onDismissalAttempt?()
        }
        return canDismissSheet
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        onDismissalAttempt?()
    }
}

struct ModalView<T: View>: UIViewControllerRepresentable {
    let view: T
    let canDismissSheet: Bool
    let onDismissalAttempt: (() -> ())?

    func makeUIViewController(context: Context) -> ModalHostingController<T> {
        let controller = ModalHostingController(rootView: view)
        if #available(iOS 16.4, *) {
            controller.safeAreaRegions = [.keyboard]
        }

        controller.canDismissSheet = canDismissSheet
        controller.onDismissalAttempt = onDismissalAttempt

        return controller
    }

    func updateUIViewController(_ uiViewController: ModalHostingController<T>, context: Context) {
        uiViewController.rootView = view

        uiViewController.canDismissSheet = canDismissSheet
        uiViewController.onDismissalAttempt = onDismissalAttempt
    }
}

extension View {
    func interactiveDismiss(canDismissSheet: Bool, onDismissalAttempt: (() -> ())? = nil) -> some View {
        ModalView(
            view: self,
            canDismissSheet: canDismissSheet,
            onDismissalAttempt: onDismissalAttempt
        ).edgesIgnoringSafeArea(.all)
    }
}
