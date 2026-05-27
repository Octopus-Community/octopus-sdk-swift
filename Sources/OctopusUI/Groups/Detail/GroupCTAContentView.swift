//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct GroupCTAContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.trackingApi) private var trackingApi
    @Environment(\.urlOpener) private var urlOpener

    let groupId: String
    let cta: GroupCTAViewData
    let topPadding: CGFloat

    var body: some View {
        HStack {
            Spacer()
            Button(action: tap) {
                Text(cta.ctaText.getText(translated: true))
                    .lineLimit(1)
            }
            .buttonStyle(OctopusButtonStyle(.mid, externalTopPadding: topPadding))
            Spacer()
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
    }

    private func tap() {
        Self.handleTap(groupId: groupId, targetUrl: cta.targetUrl,
                       trackingApi: trackingApi, urlOpener: urlOpener)
    }

    static func handleTap(groupId: String, targetUrl: URL,
                          trackingApi: TrackingApi, urlOpener: URLOpening) {
        trackingApi.trackGroupCustomActionButtonHit(groupId: groupId)
        urlOpener.open(url: targetUrl)
    }
}

// No preview — requires TrackingApi + URLOpener environment objects.
