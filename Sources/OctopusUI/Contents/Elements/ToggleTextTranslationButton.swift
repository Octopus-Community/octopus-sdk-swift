//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ToggleTextTranslationButton: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @EnvironmentObject private var trackingApi: TrackingApi
    let contentId: String
    let originalLanguage: String?

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                let newValue = translationStore.toggleDisplayTranslation(for: contentId)
                trackingApi.trackTranslationButtonHit(translationDisplayed: newValue)
            }
        }) {
            Text(localizedKey, bundle: .module)
            .font(theme.fonts.caption1)
            .fontWeight(.medium)
            .foregroundColor(theme.colors.gray700)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 8)
    }

    var localizedKey: LocalizedStringKey {
        let displayTranslation = translationStore.displayTranslation(for: contentId)
        guard displayTranslation else {
            return "Common.ViewTranslation"
        }

        if let originalLanguage {
            return "Common.ViewOriginal_language:\(originalLanguage)"
        } else {
            return "Common.ViewOriginal"
        }
    }
}
