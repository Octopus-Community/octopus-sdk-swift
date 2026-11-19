//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct UnsupportedOSVersionView: View {
    @Environment(\.textTone) private var textTone
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack(spacing: 40) {
            Image(uiImage: theme.assets.logo)
                .resizable()
                .scaledToFit()
                .frame(height: 44)

            Text("UnsupportedOS.Title", bundle: .module)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(textTone.key(formal: "UnsupportedOS.Explanation.Formal",
                              informal: "UnsupportedOS.Explanation.Informal"), bundle: .module)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
