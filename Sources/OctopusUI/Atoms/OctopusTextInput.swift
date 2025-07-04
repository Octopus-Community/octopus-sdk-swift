//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct OctopusTextInput: View {
    @Environment(\.octopusTheme) private var theme

    @Binding var text: String
    let label: LocalizedStringKey?
    let placeholder: LocalizedStringKey
    let hint: LocalizedStringKey?
    let error: DisplayableString?
    let lineLimit: Int?

    let isFocused: Bool
    let isDisabled: Bool

    let onCommit: (() -> Void)?

    init(text: Binding<String>,
         label: LocalizedStringKey? = nil,
         placeholder: LocalizedStringKey,
         hint: LocalizedStringKey? = nil,
         error: DisplayableString? = nil,
         lineLimit: Int? = 1,
         isFocused: Bool, isDisabled: Bool = false, onCommit: (() -> Void)? = nil) {
        self._text = text
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.lineLimit = lineLimit
        self.isFocused = isFocused
        self.isDisabled = isDisabled
        self.onCommit = onCommit
    }

    var body: some View {
        OctopusInput(
            label: label, hint: hint, error: error, isFocused: isFocused,
            isDisabled: isDisabled) {
                OctopusTextField(text: $text, placeholder: placeholder, lineLimit: lineLimit, onCommit: onCommit)
            }
    }
}
