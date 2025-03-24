//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct SettingProfileView: View {
    @Compat.StateObject private var viewModel: SettingProfileViewModel
    @Environment(\.octopusTheme) private var theme

    @Binding private var popToRoot: Bool
    @Binding private var preventAutoDismiss: Bool
    @State private var displayDeleteUserAlert = false

    init(octopus: OctopusSDK, popToRoot: Binding<Bool>, preventAutoDismiss: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: SettingProfileViewModel(octopus: octopus))
        _popToRoot = popToRoot
        _preventAutoDismiss = preventAutoDismiss
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

                    NavigationLink(destination: DeleteAccountView(
                        octopus: viewModel.octopus, popToRoot: $popToRoot, preventAutoDismiss: $preventAutoDismiss)) {
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
