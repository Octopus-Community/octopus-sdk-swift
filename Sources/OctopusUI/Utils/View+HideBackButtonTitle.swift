//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Hides the back button title (the name of the previous screen shown next to the chevron)
/// for any screen pushed on top of the view this modifier is applied to.
///
/// The system back button — and therefore the interactive pop gesture — is preserved.
/// On iOS 14+ this uses `UINavigationItem.backButtonDisplayMode = .minimal`.
/// On iOS 13 it falls back to setting an empty `backBarButtonItem`.
private struct HideBackButtonTitleBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        vc.view.isUserInteractionEnabled = false
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let parent = uiViewController.parent else { return }
            if #available(iOS 14.0, *) {
                parent.navigationItem.backButtonDisplayMode = .minimal
            } else {
                parent.navigationItem.backBarButtonItem = UIBarButtonItem(
                    title: "", style: .plain, target: nil, action: nil)
            }
        }
    }
}

extension View {
    /// Hides the back button title on screens pushed on top of this view.
    /// The system back button and its interactive pop gesture remain functional.
    func hideBackButtonTitle() -> some View {
        background(
            HideBackButtonTitleBridge()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}
