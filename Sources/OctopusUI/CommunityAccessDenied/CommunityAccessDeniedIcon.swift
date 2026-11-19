//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The two speech bubbles displayed above a denied access.
///
/// One drawing cut in three layers that share the same canvas, each tinted with a color of the theme, so that it
/// follows the primary color of the host app in light and in dark. Decorative, and not one of the icons a host app
/// can replace.
struct CommunityAccessDeniedIcon: View {
    @Environment(\.octopusTheme) private var theme

    @Compat.ScaledMetric(relativeTo: .title2) private var width: CGFloat = 60

    var body: some View {
        ZStack {
            // The outline of the left bubble, under its inside
            layer(.noAccessIconOutline, color: theme.colors.gray900)
            // The right bubble, and the three dots of the left one
            layer(.noAccessIconPrimary, color: theme.colors.primary)
            // The inside of the left bubble, and the two dots of the right one
            layer(.noAccessIconFill, color: theme.colors.background)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }

    private func layer(_ resource: GenImageResource, color: Color) -> some View {
        Image(res: resource)
            .resizable()
            .scaledToFit()
            .foregroundColor(color)
    }
}

#Preview {
    CommunityAccessDeniedIcon()
        .padding()
}
