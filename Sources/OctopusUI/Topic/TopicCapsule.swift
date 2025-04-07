//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct TopicCapsule: View {
    @Environment(\.octopusTheme) private var theme

    let topic: String
    
    var body: some View {
        Text(topic)
            .font(theme.fonts.caption1)
            .fontWeight(.medium)
            .foregroundColor(theme.colors.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .foregroundColor(theme.colors.primaryLowContrast)
            )
    }
}
