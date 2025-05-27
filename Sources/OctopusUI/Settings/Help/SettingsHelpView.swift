//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct SettingsHelpView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
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

                    Button(action: { navigator.push(.reportExplanation) }) {
                        SettingItem(text: "Settings.Help.ReportContent")
                    }.buttonStyle(.plain)
                }
            }
            PoweredByOctopusView()
        }
        .navigationBarTitle(Text("Settings.Help", bundle: .module), displayMode: .inline)
    }
}
