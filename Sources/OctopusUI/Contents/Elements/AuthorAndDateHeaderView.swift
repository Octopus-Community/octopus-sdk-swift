//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct AuthorAndDateHeaderView: View {
    @Environment(\.octopusTheme) private var theme

    let author: Author
    let relativeDate: String
    let displayProfile: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            OpenProfileButton(author: author, displayProfile: displayProfile) {
                author.name.textView
                    .font(theme.fonts.body2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Circle()
                .frame(width: 2, height: 2)
                .foregroundColor(theme.colors.gray900)
            Text(relativeDate)
                .font(theme.fonts.caption1)
                .foregroundColor(theme.colors.gray500)
                .lineLimit(1) // Always on one line
                .layoutPriority(1) // Ensures it does not get pushed out
        }
    }
}
