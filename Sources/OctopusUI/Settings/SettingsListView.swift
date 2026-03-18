//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

struct SettingsListView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi
    @Compat.StateObject private var viewModel: SettingsListViewModel

    @State private var displayError = false
    @State private var error: Error?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        _viewModel = Compat.StateObject(wrappedValue: SettingsListViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath))
    }

    var body: some View {
        ContentView(octopusOwnedProfile: viewModel.octopusOwnedProfile,
                    logoutInProgress: viewModel.logoutInProgress,
                    openProfile: { navigator.push(.settingsAccount) },
                    openAbout: { navigator.push(.settingsAbout) },
                    openReportContent: { navigator.push(.reportExplanation) },
                    logout: viewModel.logout)
        .navigationBarTitle(Text("Settings.Community.Title", bundle: .module))
        .emitScreenDisplayed(.settingsList, trackingApi: trackingApi)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: error,
            actions: { _ in },
            message: { error in
                Text("Error.Unknown", bundle: .module)
            })
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            self.error = error
            displayError = true
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Settings.LogOut.Done.Title", bundle: .module),
                    isPresented: $viewModel.logoutDone, actions: {
                        Button(action: { navigator.popToRoot() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.logoutDone) {
                    Alert(title: Text("Settings.LogOut.Done.Title", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.popToRoot()
                    }))
                }
            }
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let octopusOwnedProfile: Bool
    let logoutInProgress: Bool
    let openProfile: () -> Void
    let openAbout: () -> Void
    let openReportContent: () -> Void
    let logout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray300
                .frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if octopusOwnedProfile {
                        SettingItemView(image: theme.assets.icons.settings.account, titleKey: "Settings.Profile",
                                        color: theme.colors.gray900, action: openProfile)
                    }
                    SettingItemView(image: theme.assets.icons.settings.info, titleKey: "Settings.About",
                                    color: theme.colors.gray900, action: openAbout)
                    SettingItemView(image: theme.assets.icons.settings.help, titleKey: "Settings.ReportContent",
                                    color: theme.colors.gray900, action: openReportContent)
                    if octopusOwnedProfile {
                        SettingItemView(image: theme.assets.icons.settings.logout, titleKey: "Settings.LogOut.Button",
                                        color: theme.colors.error, isLoading: logoutInProgress, action: logout)
                    }
                }
            }
            PoweredByOctopusView()
        }
    }
}

private struct SettingItemView: View {
    @Environment(\.octopusTheme) private var theme

    let image: UIImage
    let titleKey: LocalizedStringKey
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    init(image: UIImage, titleKey: LocalizedStringKey, color: Color, isLoading: Bool = false,
         action: @escaping () -> Void) {
        self.image = image
        self.titleKey = titleKey
        self.color = color
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconImage(image)
                    .foregroundColor(color)
                    .accessibilityHidden(true)

                Text(titleKey, bundle: .module)
                    .fontWeight(.medium)
                    .foregroundColor(color)

                if isLoading {
                    Compat.ProgressView()
                }

                Spacer()
            }
            .font(theme.fonts.body2)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
