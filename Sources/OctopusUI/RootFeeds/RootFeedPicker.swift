//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

@available(iOS 16.0, *)
struct RootFeedPicker: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        VStack {
            Text("Feed.Filter", bundle: .module)
                .multilineTextAlignment(.center)
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
                .padding()
            CenteredFreeGridLayout {
                ForEach(rootFeeds, id: \.self) { rootFeed in
                    Button(action: {
                        selectedRootFeed = rootFeed
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(rootFeed.label)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(
                                selectedRootFeed == rootFeed ?
                                    theme.colors.textOnAccent :
                                    theme.colors.accent
                            )
                            .padding(10)
                            .background(
                                Capsule()
                                    .foregroundColor(
                                        selectedRootFeed == rootFeed ?
                                            theme.colors.accent :
                                            theme.colors.accent.opacity(0.1)
                                    )
                            )
                            .padding(6)
                    }
                }
            }
        }
        .padding()
    }
}
