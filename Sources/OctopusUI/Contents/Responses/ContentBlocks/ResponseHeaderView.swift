//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

struct ResponseHeaderView: View {
    @Environment(\.octopusTheme) private var theme

    let kind: ResponseKind
    let author: Author
    let relativeDate: String
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool

    let displayProfile: (String) -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    @Binding var iOS13ActionSheetIsPresented: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            AuthorAndDateHeaderView(
                author: author,
                relativeDate: relativeDate,
                // 10pt applied INSIDE AuthorAndDateHeaderView's tappable children so their
                // hit areas extend up to the card's top edge.
                // + 6 for the visual padding
                topPadding: 16,
                bottomPadding: 4,
                displayProfile: displayProfile)

            Spacer(minLength: 0)

            if canBeDeleted || canBeModerated || canBeBlockedByUser {
                ResponseMoreMenuButton(
                    kind: kind,
                    canBeDeleted: canBeDeleted,
                    canBeModerated: canBeModerated,
                    canBeBlockedByUser: canBeBlockedByUser,
                    onDelete: onDelete,
                    onReport: onReport,
                    onBlockAuthor: onBlockAuthor,
                    iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented)
            }
        }
        // Leading card inset only; top and bottom is handled by each child; trailing is owned by
        // ResponseMoreMenuButton's internal trailing padding (10pt).
        .padding(.leading, 12)
    }
}
