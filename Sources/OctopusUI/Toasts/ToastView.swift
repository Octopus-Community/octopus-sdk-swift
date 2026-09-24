//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ToastView: View {
    @Environment(\.octopusTheme) private var theme

    let toast: DisplayableToast
    let action: () -> Void
    /// Runs the fetch that failed again. Absent when the screen has nothing to retry.
    var retry: (() -> Void)?
    let dismiss: () -> Void

    @State private var dismissManually = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let leadingIcon = toast.leadingIcon {
                        Image(uiImage: leadingIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(foregroundColor)
                            .accessibilityHidden(true)
                    }
                        toast.message.textView
                        .font(theme.fonts.body2)
                        .foregroundColor(foregroundColor)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.leading, 16)
            }.buttonStyle(.plain)

            if let retry {
                Button(action: {
                    dismissManually = true
                    retry()
                    dismiss()
                }) {
                    Text("Common.Retry", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(foregroundColor)
                        .padding(.vertical, 16)
                        .padding(.leading, 12)
                }
                .buttonStyle(.plain)
            }

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
        .transition(.toast(isManual: dismissManually, fromTop: toast.category == .error))
    }

    var backgroundColor: Color {
        switch toast.category {
        case .info: theme.colors.primaryLowContrast
        case .success: theme.colors.successLowContrast
        // The inverse surface, as the design has it: red on red was barely readable, and an outage
        // is a status notice rather than a validation error.
        case .error: theme.colors.gray900
        }
    }

    var foregroundColor: Color {
        switch toast.category {
        case .info: theme.colors.gray900
        case .success: theme.colors.success
        case .error: theme.colors.gray100
        }
    }
}
