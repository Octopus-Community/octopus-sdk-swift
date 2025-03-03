//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateButton: View {
    enum Kind {
        case post

        fileprivate var text: LocalizedStringKey {
            switch self {
            case .post: return "Post.List.OpenCreatePost"
            }
        }
    }

    @Environment(\.octopusTheme) private var theme
    let kind: Kind
    let actionTapped: () -> Void

    var body: some View {
        Button(action: actionTapped) {
            HStack {
                Image(.createPost)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                Text(kind.text, bundle: .module)
                    .font(theme.fonts.body2)
                Spacer()
            }
            .foregroundColor(theme.colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(
                Capsule().foregroundColor(theme.colors.accent)
            )
        }
    }
}

#Preview {
    CreateButton(kind: .post, actionTapped: {})
}
