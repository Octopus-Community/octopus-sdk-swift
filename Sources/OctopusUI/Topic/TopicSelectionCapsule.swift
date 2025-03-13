//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct TopicSelectionCapsule: View {
    @Environment(\.octopusTheme) private var theme

    let topic: String?

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let topic {
                    Text(topic)
                } else {
                    Text("Post.Create.Topic.Selection.Button", bundle: .module)
                }
            }
            Image(systemName: "chevron.down")
        }
        .font(theme.fonts.caption1.weight(.semibold))
        .foregroundColor(theme.colors.gray900)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Capsule()
            .foregroundColor(theme.colors.gray300))
    }
}

#Preview {
    TopicSelectionCapsule(topic: nil)
}
