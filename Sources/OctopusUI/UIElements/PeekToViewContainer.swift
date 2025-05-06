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
