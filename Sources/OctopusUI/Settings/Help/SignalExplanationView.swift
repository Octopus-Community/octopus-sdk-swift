//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct SignalExplanationView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray200.frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                HStack(alignment: .top) {
                    Image(.Settings.info)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(theme.colors.gray600)

                    VStack(alignment: .leading, spacing: 20) {
                        Text("Settings.Report.MainText", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray600)

                        Text("Settings.Report.Explanation", bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(theme.colors.gray500)
                            .lineSpacing(8)

                        if #available(iOS 15.0, *) {
                            Text("Settings.Help.ContactUs.Questions.Link",
                                 bundle: .module)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .tint(theme.colors.link)
                            .environment(\.openURL, OpenURLAction { _ in
                                UIApplication.shared.open(ExternalLinks.communityGuidelines)
                                return .handled
                            })
                        } else {
                            Compat.Link(destination: ExternalLinks.communityGuidelines) {
                                Text("Settings.Help.ContactUs.Questions.NoLink", bundle: .module)
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
        }
        .navigationBarTitle(Text("Settings.Help.ReportContent", bundle: .module), displayMode: .inline)
    }

    var contentPolicyView: some View {
        WebView(url: ExternalLinks.communityGuidelines)
            .navigationBarTitle(Text("Settings.CommunityGuidelines", bundle: .module), displayMode: .inline)
    }
}
