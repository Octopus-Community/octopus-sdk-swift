//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Available nicknames proposed after a taken one. They scroll horizontally when they do not fit, the last
/// visible one being cut to show there are more.
struct NicknameSuggestionsView: View {
    @Environment(\.octopusTheme) private var theme

    let suggestions: [String]
    let pick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { pick(suggestion) }) {
                        Text(suggestion)
                            .font(theme.fonts.caption1)
                            .foregroundColor(theme.colors.gray900)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().stroke(theme.colors.gray300, lineWidth: 1))
                            // A tap target of at least 44x44pt around the capsule, which keeps its look. It also
                            // keeps the stroke off the scroll view's top and bottom edges, which clip it.
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
