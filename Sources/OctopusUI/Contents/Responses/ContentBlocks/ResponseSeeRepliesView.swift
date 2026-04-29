//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

struct ResponseSeeRepliesView: View {
    @Environment(\.octopusTheme) private var theme

    let childCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(uiImage: theme.assets.icons.content.comment.seeReply)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundColor(theme.colors.primary)
                Text("Reply.See_count:\(childCount)", bundle: .module)
                    .font(theme.fonts.caption1)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.primary)
                Spacer(minLength: 0)
            }
            // Figma: outer `pb-[12px]` + inner `py-[5px]`. Total: 5pt top, 17pt bottom.
            .padding(.vertical, 5)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ResponseSeeRepliesView(childCount: 18, onTap: {})
        .padding()
        .mockEnvironmentForPreviews()
}
