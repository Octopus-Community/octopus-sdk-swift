//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct SettingsHelpView: View {
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
                VStack(alignment: .leading, spacing: 20) {
                    SettingLinkItem(text: "Settings.Help.FAQ.Title", url: viewModel.faq)

                    NavigationLink(destination: SignalExplanationView(octopus: viewModel.octopus)) {
                        SettingItem(text: "Settings.Help.ReportContent")
                    }

                    SettingLinkItem(text: "Settings.Help.ContactUs", url: viewModel.contactUs)
                }
            }
        }
        .navigationBarTitle(Text("Settings.Help", bundle: .module), displayMode: .inline)
    }
}
