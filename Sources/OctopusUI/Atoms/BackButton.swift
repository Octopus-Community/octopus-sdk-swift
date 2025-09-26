//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct BackButton: View {
    @Environment(\.octopusTheme) private var theme

    let action: () -> Void

    var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(theme.fonts.navBarItem.weight(.semibold))
                    .contentShape(Rectangle())
            }
        } else {
            Button(action: action) {
                Image(systemName: "chevron.left")
                    .font(theme.fonts.navBarItem.weight(.semibold))
                    .contentShape(Rectangle())
                    .padding(.trailing, 40)
            }
            .padding(.leading, -8)
        }
#else
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(theme.fonts.navBarItem.weight(.semibold))
                .contentShape(Rectangle())
                .padding(.trailing, 40)
        }
        .padding(.leading, -8)
#endif
    }
}

#Preview {
    CreateButton(kind: .post, actionTapped: {})
}
