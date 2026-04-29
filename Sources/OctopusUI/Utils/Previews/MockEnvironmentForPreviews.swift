//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

extension View {
    /// Injects the same environment values + environment objects that `OctopusHomeScreen`
    /// provides, using preview-safe no-op implementations. Apply to any SwiftUI preview in
    /// OctopusUI to let the view render without manual setup.
    ///
    /// Covers: `octopusTheme`, `urlOpener`, `trackingApi`, `ContentTranslationPreferenceStore`,
    /// `GamificationRulesViewManager`, `DisplayConfigManager`, `VideoManager`, `LanguageManager`.
    func mockEnvironmentForPreviews() -> some View {
        self
            .environment(\.octopusTheme, OctopusTheme())
            .environment(\.urlOpener, NoopURLOpener())
            .environment(\.trackingApi, NoopTrackingApi())
            .environmentObject(ContentTranslationPreferenceStore.forPreviews())
            .environmentObject(GamificationRulesViewManager.forPreviews())
            .environmentObject(DisplayConfigManager.forPreviews())
            .environmentObject(VideoManager.forPreviews())
            .environmentObject(LanguageManager.forPreviews())
    }
}
