//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct GamificationProgressionBar: View {
    @Environment(\.octopusTheme) private var theme

    let currentScore: Int
    let startScore: Int
    let targetScore: Int

    @State private var width: CGFloat = 1
    private let height: CGFloat = 6

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(theme.colors.primaryLowContrast)
                .frame(height: height)

            Capsule()
                .fill(theme.colors.primaryHighContrast)
                .frame(
                    // when percentage is not 0, have a minimal width equal to the height to see the rounded corners
                    width: percentage > 0 ? max(width * percentage, height) : 0,
                    height: height)
        }
        .readWidth($width)
    }

    var percentage: Double {
        let levelTarget = targetScore - startScore
        let currentScoreInLevel = currentScore - startScore
        return min(Double(currentScoreInLevel) / Double(levelTarget), 1.0)
    }
}
