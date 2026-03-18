//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ToastView: View {
    @Environment(\.octopusTheme) private var theme

    let toast: DisplayableToast
    let action: () -> Void
    let dismiss: () -> Void

    @State private var dismissManually = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                toast.message.textView
                    .font(theme.fonts.body2)
                    .foregroundColor(foregroundColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 16)
                    .padding(.leading, 16)
            }.buttonStyle(.plain)

            Button(action: {
                dismissManually = true
                dismiss()
            }) {
                IconImage(theme.assets.icons.common.close)
                    .font(theme.fonts.body2)
                    .foregroundColor(foregroundColor)
                    .accessibilityLabelInBundle("Accessibility.Toast.Close")
                    .padding(.vertical, 16)
                    .padding(.trailing, 16)
                    .padding(.leading, 12)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
                .shadow(radius: 2, y: 2)
        )
        .padding(.horizontal, 16)
        .transition(.toast(isManual: dismissManually))
    }

    var backgroundColor: Color {
        switch toast.category {
        case .info: theme.colors.primaryLowContrast
        case .success: theme.colors.successLowContrast
        case .error: theme.colors.errorLowContrast
        }
    }

    var foregroundColor: Color {
        switch toast.category {
        case .info: theme.colors.gray900
        case .success: theme.colors.success
        case .error: theme.colors.error
        }
    }
}
