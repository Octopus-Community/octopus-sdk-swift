//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

struct PostGroupLinkView: View {
    @Environment(\.octopusTheme) private var theme

    let groupName: String
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
        .contentShape(Rectangle())
    }

    private var label: some View {
        HStack {
            Text(groupName)
                .font(theme.fonts.caption1)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

#Preview("Tappable") {
    PostGroupLinkView(groupName: "Groupe", onTap: {})
        .padding()
}

#Preview("Plain") {
    PostGroupLinkView(groupName: "Groupe", onTap: nil)
        .padding()
}
