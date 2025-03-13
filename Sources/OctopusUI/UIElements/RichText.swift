//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct RichText: View {
    @Environment(\.octopusTheme) private var theme
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if #available(iOS 15, *) {
            Text((try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
                .tint(theme.colors.link)
                .textSelection(.enabled)
        } else {
            Text(text)
        }
    }
}
