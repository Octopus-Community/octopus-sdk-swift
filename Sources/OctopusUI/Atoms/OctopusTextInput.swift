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
    let lineLimitValue: Int?
    let lineLimitRange: PartialRangeFrom<Int>?

    @Binding var isFocused: Bool
    let isDisabled: Bool

    let onCommit: (() -> Void)?

    init(text: Binding<String>,
         label: LocalizedStringKey? = nil,
         placeholder: LocalizedStringKey,
         hint: LocalizedStringKey? = nil,
         error: DisplayableString? = nil,
         lineLimit: Int? = 1,
         lineLimitRange: PartialRangeFrom<Int>? = nil,
         isFocused: Binding<Bool>, isDisabled: Bool = false, onCommit: (() -> Void)? = nil) {
        self._text = text
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.error = error
        self.lineLimitValue = lineLimit
        self.lineLimitRange = lineLimitRange
        self._isFocused = isFocused
        self.isDisabled = isDisabled
        self.onCommit = onCommit
    }

    var body: some View {
        OctopusInput(
            label: label, hint: hint, error: error, isFocused: isFocused,
            isDisabled: isDisabled) {
                OctopusTextField(
                    text: $text,
                    placeholder: placeholder,
                    lineLimit: lineLimitValue,
                    lineLimitRange: lineLimitRange,
                    onCommit: onCommit
                )
                .padding(12)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }
    }
}
