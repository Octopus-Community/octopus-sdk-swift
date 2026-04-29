//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostCTAContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.trackingApi) private var trackingApi
    @Environment(\.urlOpener) private var urlOpener

    let postId: String
    let cta: PostCTAViewData
    /// Provided in bridge mode by the caller.
    let displayClientObject: ((String) -> Void)?

    var body: some View {
        HStack {
            Spacer()
            Button(action: tap) {
                Text(cta.text.getText(translated: true))
                    .lineLimit(1)
            }
            .buttonStyle(OctopusButtonStyle(.mid, externalTopPadding: 10))
            Spacer()
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
    }

    private func tap() {
        switch cta.action {
        case let .bridge(objectId):
            displayClientObject?(objectId)
        case let .openURL(url):
            trackingApi.trackPostCustomActionButtonHit(postId: postId)
            urlOpener.open(url: url)
        }
    }
}

// No preview — requires TrackingApi environment object
