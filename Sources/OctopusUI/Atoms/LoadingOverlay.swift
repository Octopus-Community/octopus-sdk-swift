//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// A centered progress indicator with a material/gray background pill.
/// Used as a loading overlay on top of content during destructive or long-running operations.
struct LoadingOverlay: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        Compat.ProgressView()
            .padding(20)
            .background(
                RoundedRectangle(cornerSize: CGSize(width: 4, height: 4))
                    .modify {
                        if #available(iOS 15.0, *) {
                            $0.fill(.thickMaterial)
                        } else {
                            $0.fill(theme.colors.gray200)
                        }
                    }
            )
    }
}
