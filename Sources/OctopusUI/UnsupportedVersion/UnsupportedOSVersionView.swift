//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct UnsupportedOSVersionView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack(spacing: 40) {
            Image(uiImage: theme.assets.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 44)

            Text("UnsupportedOS.Title", bundle: .module)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("UnsupportedOS.Explanation", bundle: .module)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}
