//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Compat {
    struct Link<Content: View>: View {
        let destination: URL
        @ViewBuilder let label: () -> Content

        var body: some View {
            if #available(iOS 14.0, *) {
                SwiftUI.Link(destination: destination, label: label)
                    .buttonStyle(.plain)
            } else {
                Button(
                    action: {
                        UIApplication.shared.open(destination)
                    },
                    label: label)
                .buttonStyle(.plain)
            }
        }
    }
}
