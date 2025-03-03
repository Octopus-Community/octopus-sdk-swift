//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct SettingsAboutView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray200.frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingLinkItem(text: "Settings.CommunityGuidelines",
                                    url: ExternalLinks.communityGuidelines)

                    SettingLinkItem(text: "Settings.PrivacyPolicy",
                                    url: ExternalLinks.privacyPolicy)

                    SettingLinkItem(text: "Settings.TermsOfUse",
                                    url: ExternalLinks.termsOfUse)
                }
            }
        }
        .navigationBarTitle(Text("Settings.About", bundle: .module), displayMode: .inline)
    }
}
