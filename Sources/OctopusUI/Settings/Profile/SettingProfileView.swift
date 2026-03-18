//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct SettingProfileView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi
    @Compat.StateObject private var viewModel: SettingProfileViewModel
    @Environment(\.octopusTheme) private var theme

    @State private var displayDeleteUserAlert = false

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: SettingProfileViewModel(octopus: octopus))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray300.frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 12) {
                        IconImage(theme.assets.icons.settings.info)
                            .foregroundColor(theme.colors.gray900)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 20) {
                            Text("Settings.Profile.Email", bundle: .module)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.gray900)

                            Text(viewModel.email ?? "")
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.gray500)
                                .onTapGesture {
                                    guard viewModel.email?.nilIfEmpty != nil else { return }
                                    UIPasteboard.general.string = viewModel.email
                                }
                        }
                        Spacer()
                    }
                    .font(theme.fonts.body2)

                    Button(action: { navigator.push(.deleteAccount) }) {
                        HStack(alignment: .top, spacing: 12) {
                            IconImage(theme.assets.icons.settings.logout)
                                .foregroundColor(theme.colors.error)
                                .accessibilityHidden(true)

                            Text("Settings.Profile.DeleteAccount.OpenScreen", bundle: .module)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.error)

                            Spacer()
                        }
                        .font(theme.fonts.body2)
                    }.buttonStyle(.plain)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
            PoweredByOctopusView()
        }
        .navigationBarTitle(Text("Settings.Profile", bundle: .module), displayMode: .inline)
        .emitScreenDisplayed(.settingsAccount, trackingApi: trackingApi)
    }
}
