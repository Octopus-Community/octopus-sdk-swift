//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct DefaultEmptyPostsView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(res: .noPosts)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text("Post.List.Default.Empty", bundle: .module)
                .font(theme.fonts.body2)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(theme.colors.gray700)
        .padding(.horizontal)
    }
}

struct CreatePostEmptyPostView: View {
    @Environment(\.octopusTheme) private var theme

    let createPost: (_ withPoll: Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Image(res: .noCurrentUserPost)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(theme.colors.gray900)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            Spacer().frame(height: 16)
            Text("Post.Create.Incentive.Explanation", bundle: .module)
                .font(theme.fonts.body1)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray900)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 24)
            if #available(iOS 16.0, *) {
                FreeGridLayout {
                    CurrentUserIncentiveButtons(createPost: createPost)
                }
            } else {
                VStack {
                    CurrentUserIncentiveButtons(createPost: createPost)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct CurrentUserIncentiveButtons: View {
    let createPost: (_ withPoll: Bool) -> Void

    var body: some View {
        CurrentUserIncentiveButton("Post.Create.Incentive.Button1", createPost: createPost)
        CurrentUserIncentiveButton("Post.Create.Incentive.Button2", createPost: createPost)
        CurrentUserIncentiveButton("Post.Create.Incentive.Button3", createPost: createPost)
        CurrentUserIncentiveButton("Post.Create.Incentive.Button4", createPost: createPost)
        CurrentUserIncentiveButton("Post.Create.Incentive.Button5", openPoll: true, createPost: createPost)
        CurrentUserIncentiveButton("Post.Create.Incentive.Button6", createPost: createPost)
    }
}

private struct CurrentUserIncentiveButton: View {
    let text: LocalizedStringKey
    let openPoll: Bool
    let createPost: (_ withPoll: Bool) -> Void

    init(_ text: LocalizedStringKey, openPoll: Bool = false, createPost: @escaping (_: Bool) -> Void) {
        self.text = text
        self.openPoll = openPoll
        self.createPost = createPost
    }

    var body: some View {
        Button(action: { createPost(openPoll) }) {
            Text(text, bundle: .module)
        }
        .buttonStyle(OctopusButtonStyle(.mid, style: .outline,
                                        externalVerticalPadding: 6, externalHorizontalPadding: 4))
    }
}

struct OtherUserEmptyPostView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(res: .noPosts)
                .accessibilityHidden(true)
            Text("Post.List.OtherUser.Empty", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(theme.colors.gray500)
        .padding(.horizontal)
    }
}
