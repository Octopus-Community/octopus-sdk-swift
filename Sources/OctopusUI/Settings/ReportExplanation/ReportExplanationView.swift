//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ReportExplanationView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var trackingApi: TrackingApi
    @Compat.StateObject private var viewModel: LinksProviderViewModel

    @Compat.ScaledMetric(relativeTo: .title1) var iconSize: CGFloat = 20 // title1 to vary from 18 to 40

    var explanationString: String {
        String.localizedStringWithFormat(
            Bundle.module.localizedString(forKey: "Settings.Report.Explanation_url:%@", value: nil, table: nil),
            viewModel.communityGuidelines.absoluteString
        )
    }

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: LinksProviderViewModel(octopus: octopus))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray300.frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                HStack(alignment: .top) {
                    Image(res: .Settings.info)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(theme.colors.gray900)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Settings.Report.MainText", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray900)

                        RichText(explanationString)
                            .font(theme.fonts.body2.weight(.medium))
                            .foregroundColor(theme.colors.gray500)
                            .lineSpacing(8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            PoweredByOctopusView()
        }
        .navigationBarTitle(Text("Settings.ReportContent", bundle: .module), displayMode: .inline)
        .emitScreenDisplayed(.reportExplanation, trackingApi: trackingApi)
    }

    var contentPolicyView: some View {
        WebView(url: viewModel.communityGuidelines)
            .navigationBarTitle(Text("Settings.CommunityGuidelines", bundle: .module), displayMode: .inline)
    }
}
