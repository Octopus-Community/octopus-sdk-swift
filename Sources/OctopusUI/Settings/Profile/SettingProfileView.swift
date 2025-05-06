//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct SettingProfileView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
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
                        Image(.Settings.info)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundColor(theme.colors.gray900)

                        VStack(alignment: .leading, spacing: 20) {
                            Text("Settings.Profile.Email", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.gray900)

                            Text(viewModel.email ?? "")
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.gray500)
                                .onTapGesture {
                                    guard viewModel.email?.nilIfEmpty != nil else { return }
                                    UIPasteboard.general.string = viewModel.email
                                }
                        }
                        Spacer()
                    }

                    Button(action: { navigator.push(.deleteAccount) }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(.Settings.logout)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(theme.colors.error)

                            Text("Settings.Profile.DeleteAccount.OpenScreen", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.error)

                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .navigationBarTitle(Text("Settings.Profile", bundle: .module), displayMode: .inline)
    }
}
