//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus

struct OpenUserProfileBubbleView: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: OpenUserProfileBubbleViewModel

    let userProfileTapped: () -> Void

    init(octopus: OctopusSDK, userProfileTapped: @escaping () -> Void) {
        _viewModel = Compat.StateObject(wrappedValue: OpenUserProfileBubbleViewModel(octopus: octopus))
        self.userProfileTapped = userProfileTapped
    }

    var body: some View {
        Button(action: userProfileTapped) {
            ZStack(alignment: .topTrailing) {
                if viewModel.isUnifiedProfileActive {
                    // Unified Profile (OCT-1374): the home floating button opens the community Activity
                    // screen, so it shows a community-activity glyph (client-overridable via
                    // `common.activityButton`) on a primary-filled circle instead of the user's avatar.
                    // The unread-notification badge overlay stays the same as the avatar case.
                    Image(uiImage: theme.assets.icons.common.activityButton)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(theme.colors.onPrimary)
                        .padding(10)
                        .frame(width: 50, height: 50)
                        .background(theme.colors.primary)
                        .clipShape(Circle())
                        .accessibilityLabelInBundle("Activity.Screen.Title")
                } else {
                    AuthorAvatarView(avatar: viewModel.avatar)
                        .frame(width: 50, height: 50)
                }

                if let badgeCount = viewModel.badgeCount {
                    Text(badgeCount)
                        .font(theme.fonts.caption2.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            Group {
                                if badgeCount.count == 1 {
                                    Circle()
                                        .fill(theme.colors.error)
                                } else {
                                    Capsule()
                                        .fill(theme.colors.error)
                                }
                            }
                        )
                        .padding(.vertical, -8)
                        .padding(.horizontal, -6)
                }
            }

        }
        .buttonStyle(.plain)
    }
}
