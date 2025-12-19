//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct HVStack<Content: View>: View {
    var spacing: CGFloat? = nil
    let isHorizontal: Bool
    @ViewBuilder let content: Content

    var body: some View {
        if isHorizontal {
            HStack(spacing: spacing) { content }
        } else {
            VStack(spacing: spacing) { content }
        }
    }
}
