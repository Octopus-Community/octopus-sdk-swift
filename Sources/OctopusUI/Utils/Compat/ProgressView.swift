//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    struct ProgressView: View {

        let tint: Color?

        init(tint: Color? = nil) {
            self.tint = tint
        }

        var body: some View {
            if #available(iOS 14.0, *) {
                SwiftUI.ProgressView()
                    .modify {
                        if #available(iOS 15.0, *) {
                            $0.tint(tint)
                        } else if let tint {
                            $0.progressViewStyle(CircularProgressViewStyle(tint: tint))
                        } else {
                            $0
                        }
                    }
            } else {
                ActivityIndicator()
            }
        }
    }
}

private struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        let view = UIActivityIndicatorView(style: .medium)
        view.startAnimating()
        view.hidesWhenStopped = true
        return view
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
    }
}
