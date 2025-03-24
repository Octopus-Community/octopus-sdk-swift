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
            Image(.postDetailMissing)
            Text("Post.List.Empty", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray500)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
}

struct CreatePostEmptyPostView: View {
    @Environment(\.octopusTheme) private var theme

    let createPost: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: 54)
            Image(.postDetailMissing)
            Text("Post.Create.Incentive.Explanation", bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray500)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 54)
            Button(action: createPost) {
                Text("Post.Create.Incentive.Button", bundle: .module)
                    .font(theme.fonts.body2)
                    .foregroundColor(theme.colors.onPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.colors.primary)
                    )
            }.buttonStyle(.plain)
        }
    }
}
