//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct OctopusInput<InputView: View>: View {
    @Environment(\.octopusTheme) private var theme

    let inputView: () -> InputView
    let label: LocalizedStringKey?
    let hint: LocalizedStringKey?
    let error: DisplayableString?

    let isFocused: Bool
    let isDisabled: Bool

    init(
        label: LocalizedStringKey? = nil,
        hint: LocalizedStringKey? = nil,
        error: DisplayableString? = nil,
        isFocused: Bool, isDisabled: Bool = false,
        @ViewBuilder inputView: @escaping () -> InputView) {
            self.label = label
            self.hint = hint
            self.error = error
            self.isFocused = isFocused
            self.isDisabled = isDisabled
            self.inputView = inputView
        }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let label {
                Text(label, bundle: .module)
                    .font(theme.fonts.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray700)
                    .accessibilityAddTraits(.isHeader)
            }

            inputView()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDisabled ? theme.colors.disabledBg : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
                        )
                        .padding(1)
                )

            if let error {
                error.textView
                    .font(theme.fonts.caption2)
                    .fontWeight(.regular)
                    .foregroundColor(theme.colors.error)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let hint {
                Text(hint, bundle: .module)
                    .font(theme.fonts.caption2)
                    .fontWeight(.regular)
                    .foregroundColor(theme.colors.gray700)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var borderColor: Color {
        guard error == nil else { return theme.colors.error }
        guard !isDisabled else { return theme.colors.gray300 }
        guard isFocused else { return theme.colors.gray300 }
        return theme.colors.primary
    }
}
