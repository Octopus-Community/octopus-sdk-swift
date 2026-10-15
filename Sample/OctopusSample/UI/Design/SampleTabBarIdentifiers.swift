//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Gives the tab bar buttons the Android test ids (`scenarios-tab`, …), in tab order.
    ///
    /// SwiftUI drops an `accessibilityIdentifier` set on a tab label: the system tab bar draws its own
    /// buttons from the label's title and image. The ids are therefore set on the underlying
    /// `UITabBarItem`s, which is what the tab bar buttons expose to UI tests and to `idb`.
    func sampleTabBarIdentifiers(_ identifiers: [String]) -> some View {
        background(TabBarIdentifiersSetter(identifiers: identifiers).frame(width: 0, height: 0))
    }
}

private struct TabBarIdentifiersSetter: UIViewControllerRepresentable {
    let identifiers: [String]

    func makeUIViewController(context: Context) -> Controller {
        Controller(identifiers: identifiers)
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.identifiers = identifiers
        controller.apply()
    }

    final class Controller: UIViewController {
        var identifiers: [String]

        init(identifiers: [String]) {
            self.identifiers = identifiers
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }

        func apply() {
            guard let items = tabBarController?.tabBar.items else { return }
            for (item, identifier) in zip(items, identifiers) {
                item.accessibilityIdentifier = identifier
            }
        }
    }
}
