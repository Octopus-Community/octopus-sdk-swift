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
                AuthorAvatarView(avatar: viewModel.avatar)
                    .frame(width: 50, height: 50)

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
