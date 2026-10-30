//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct OctopusTextField: View {
    @Environment(\.octopusTheme) private var theme

    @Binding var text: String
    let placeholder: LocalizedStringKey
    let lineLimitValue: Int?
    let lineLimitRange: PartialRangeFrom<Int>?

    /// Called when the user submits the field from the keyboard.
    /// - Warning: on a multi-line field (iOS 16+), passing it attaches `onSubmit`, which keeps the text already typed
    ///   in the colour of the previous appearance after a light/dark switch, until the next keystroke. Leave it `nil`
    ///   on multi-line fields unless that is acceptable.
    let onCommit: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: LocalizedStringKey,
        lineLimit: Int? = nil,
        lineLimitRange: PartialRangeFrom<Int>? = nil,
        onCommit: (() -> Void)? = nil) {
            self._text = text
            self.placeholder = placeholder
            self.lineLimitValue = lineLimit
            self.lineLimitRange = lineLimitRange
            self.onCommit = onCommit
        }

    var body: some View {
        Group {
            if #available(iOS 16.0, *), lineLimitValue != 1 || lineLimitRange != nil {
                TextField(String(""), text: $text, axis: .vertical)
                    .modify {
                        // `onSubmit` on a vertical field freezes the colour of the text already typed: after a
                        // light/dark switch it keeps the old appearance's colour until the next keystroke, which
                        // leaves it unreadable. Only attach it when there is something to submit.
                        if let onCommit {
                            $0.onSubmit(onCommit)
                        } else { $0 }
                    }
            } else {
                // TODO: create a TextField that expands vertically on iOS 13
                TextField(String(""), text: $text, onCommit: onCommit ?? {})
            }
        }
        .accessibilityLabelInBundle(placeholder)
        .modify {
            if let lineLimitRange {
                if #available(iOS 16.0, *) {
                    $0.lineLimit(lineLimitRange)
                } else {
                    $0.lineLimit(nil)
                }
            } else {
                $0.lineLimit(lineLimitValue)
            }
        }
        .multilineTextAlignment(.leading)
        .foregroundColor(theme.colors.gray900)
        .placeholder(when: text.isEmpty) {
            Text(placeholder, bundle: .module)
                .multilineTextAlignment(.leading)
                .foregroundColor(theme.colors.gray500)
                .accessibilityHidden(true)
        }
        .font(theme.fonts.body2)
        .frame(maxWidth: .infinity)
    }
}
