//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct SettingsHelpView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray200.frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingLinkItem(text: "Settings.Help.FAQ.Title", url: ExternalLinks.faq)

                    SettingLinkItem(text: "Settings.Help.ReportProblem", url: ExternalLinks.reportIssue)

                    NavigationLink(destination: SignalExplanationView()) {
                        SettingItem(text: "Settings.Help.ReportContent")
                    }

                    NavigationLink(destination: ContactUsView()) {
                        SettingItem(text: "Settings.Help.ContactUs.Title")
                    }
                }
            }
        }
        .navigationBarTitle(Text("Settings.Help", bundle: .module), displayMode: .inline)
    }
}
