//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct PeekToViewContainer<Item, Content: View>: View {
    @Binding var item: Item?
    @ViewBuilder var content: () -> Content

    @State private var hideOtherElements = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Neutral backdrop for the full-screen media viewer — intentionally NOT the themeable
            // community background. Under the forced dark color scheme this reads as black, keeping
            // the photo/video letterbox area neutral regardless of a custom community background color.
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            content()
                .clipped()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.identity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
