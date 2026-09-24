//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// What a content area shows instead of a list: nothing to display, or a first load that failed.
///
/// One component for every such state across the SDK — profile tabs, main feed, group, explore, post and
/// comment — so a single visual language covers them all. It carries a picture, a title and an optional
/// call to action; the vertical padding is per-screen, which is the only thing the design varies.
struct ScreenState: View {
    /// The call to action, when the state offers one — "Retry" on an error, "Create a post" on the
    /// current user's empty feed. Absent on the states that leave nothing to do, such as another
    /// member's empty profile.
    struct Action {
        let title: LocalizedStringKey
        let handler: () -> Void

        init(title: LocalizedStringKey, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    @Environment(\.octopusTheme) private var theme

    let image: UIImage
    let title: DisplayableString
    var action: Action?
    /// Space above and below, which the design sets per screen (80 on the profile, 100 on an empty feed,
    /// 40 on a post's comments…).
    var verticalPadding: CGFloat = 80

    @Compat.ScaledMetric(relativeTo: .body) private var imageHeight: CGFloat = 104

    /// Vertical paddings the design gives per screen.
    static let profilePadding: CGFloat = 80
    static let feedEmptyPadding: CGFloat = 100
    static let feedErrorPadding: CGFloat = 80
    static let explorePadding: CGFloat = 120
    static let postEmptyPadding: CGFloat = 60
    static let postErrorPadding: CGFloat = 40
    static let commentPadding: CGFloat = 60

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: imageHeight)
            title.textView
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray500)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: action.handler) {
                    Text(action.title, bundle: .module)
                }
                .buttonStyle(OctopusButtonStyle(.mid, style: .outline))
                // Sits on its own line under the title, never stretched to the full width.
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, theme.sizes.horizontalPadding)
        .padding(.vertical, verticalPadding)
        // One element for VoiceOver: the picture is decorative, the title carries the meaning.
        .accessibilityElement(children: .combine)
    }
}
