//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct SignalExplanationView: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: LinksProviderViewModel

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
                    Image(.Settings.info)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(theme.colors.gray900)

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Settings.Report.MainText", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray900)

                        Text("Settings.Report.Explanation", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray500)
                            .lineSpacing(8)

                        if #available(iOS 15.0, *) {
                            Text("Settings.Report.CommunityGuidelines.Link",
                                 bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .tint(theme.colors.link)
                            .environment(\.openURL, OpenURLAction { _ in
                                UIApplication.shared.open(viewModel.communityGuidelines)
                                return .handled
                            })
                        } else {
                            Compat.Link(destination: viewModel.communityGuidelines) {
                                Text("Settings.Report.CommunityGuidelines.NoLink", bundle: .module)
                                    .font(theme.fonts.body2)
                                    .fontWeight(.medium)
                                    .foregroundColor(theme.colors.link)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            PoweredByOctopusView()
        }
        .navigationBarTitle(Text("Settings.Help.ReportContent", bundle: .module), displayMode: .inline)
    }

    var contentPolicyView: some View {
        WebView(url: viewModel.communityGuidelines)
            .navigationBarTitle(Text("Settings.CommunityGuidelines", bundle: .module), displayMode: .inline)
    }
}
