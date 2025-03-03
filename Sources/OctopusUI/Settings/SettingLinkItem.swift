//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct SettingLinkItem: View {
    @Environment(\.octopusTheme) private var theme

    let text: LocalizedStringKey
    let url: URL

    var body: some View {
        Compat.Link(destination: url) {
            SettingItem(text: text)
        }
    }
}

struct SettingItem: View {
    @Environment(\.octopusTheme) private var theme

    let text: LocalizedStringKey

    var body: some View {
        Text(text, bundle: .module)
            .font(theme.fonts.body2)
            .fontWeight(.medium)
            .foregroundColor(theme.colors.gray600)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }
}
