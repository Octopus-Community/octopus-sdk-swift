//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import OctopusCore
import SwiftUI

/// A view modifier that presents the gamification rules screen as a sheet.
/// Encapsulates the conditional check on `gamificationConfig` and the `EmptyView` fallback.
struct GamificationRulesSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let gamificationConfig: GamificationConfig?
    let gamificationRulesViewManager: GamificationRulesViewManager

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if let gamificationConfig {
                GamificationRulesScreen(gamificationConfig: gamificationConfig,
                                        gamificationRulesViewManager: gamificationRulesViewManager
                ).sizedSheet()
            } else {
                EmptyView()
            }
        }
    }
}

extension View {
    func gamificationRulesSheet(
        isPresented: Binding<Bool>,
        gamificationConfig: GamificationConfig?,
        gamificationRulesViewManager: GamificationRulesViewManager
    ) -> some View {
        modifier(GamificationRulesSheetModifier(
            isPresented: isPresented,
            gamificationConfig: gamificationConfig,
            gamificationRulesViewManager: gamificationRulesViewManager))
    }
}
