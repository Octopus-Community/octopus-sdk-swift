//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct LoadingView<Content: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            content
                .disabled(isLoading)
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                Compat.ProgressView()
            }
        }
    }
}
