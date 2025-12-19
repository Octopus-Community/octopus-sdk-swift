//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// A view that embeds its content in a button if `embedInButton` is true. Otherwise it display the content directly.
struct ButtonOrContent<Content: View>: View {
    let embedInButton: Bool
    let action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        if embedInButton {
            Button(action: action) {
                content
                    .contentShape(Rectangle())
            }
        } else {
            content
        }
    }
}
