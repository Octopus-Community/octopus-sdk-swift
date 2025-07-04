//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct OctopusTextField: View {
    @Environment(\.octopusTheme) private var theme

    @Binding var text: String
    let placeholder: LocalizedStringKey
    let lineLimit: Int?

    let onCommit: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: LocalizedStringKey,
        lineLimit: Int? = nil,
        onCommit: (() -> Void)? = nil) {
            self._text = text
            self.placeholder = placeholder
            self.lineLimit = lineLimit
            self.onCommit = onCommit
        }

    var body: some View {
        Group {
            if #available(iOS 16.0, *), lineLimit != 1 {
                TextField(String(""), text: $text, axis: .vertical)
                    .onSubmit { onCommit?() }
            } else {
                // TODO: create a TextField that expands vertically on iOS 13
                TextField(String(""), text: $text, onCommit: onCommit ?? {})
            }
        }
        .lineLimit(lineLimit)
        .multilineTextAlignment(.leading)
        .foregroundColor(theme.colors.gray900)
        .placeholder(when: text.isEmpty) {
            Text(placeholder, bundle: .module)
                .multilineTextAlignment(.leading)
                .foregroundColor(theme.colors.gray500)
        }
        .font(theme.fonts.body2)
        .frame(maxWidth: .infinity)
    }
}
