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
            Image(.noPosts)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
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

    let createPost: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(.noPosts)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(theme.colors.gray700)
                .frame(width: 64, height: 64)
            Text("Post.Create.Incentive.Explanation", bundle: .module)
                .font(theme.fonts.body2)
                .foregroundColor(theme.colors.gray700)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 24)
            Button(action: createPost) {
                Text("Post.Create.Incentive.Button", bundle: .module)
            }
            .buttonStyle(OctopusButtonStyle(.main))
        }
    }
}

struct OtherUserEmptyPostView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(.noPosts)
            Text("Post.List.OtherUser.Empty", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(theme.colors.gray500)
        .padding(.horizontal)
    }
}
