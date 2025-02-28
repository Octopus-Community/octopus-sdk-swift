//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

struct SettingsListView: View {
    @Compat.StateObject private var viewModel: SettingsListViewModel

    @Binding private var popToRoot: Bool
    @Binding private var preventAutoDismiss: Bool

    @State private var displayError = false
    @State private var error: Error?

    @State private var openProfile = false
    @State private var openAbout = false
    @State private var openHelp = false

    init(octopus: OctopusSDK, popToRoot: Binding<Bool>, preventAutoDismiss: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: SettingsListViewModel(octopus: octopus))
        _popToRoot = popToRoot
        _preventAutoDismiss = preventAutoDismiss
    }

    var body: some View {
        ContentView(octopusOwnedProfile: viewModel.octopusOwnedProfile,
                    logoutInProgress: viewModel.logoutInProgress,
                    openProfile: { openProfile = true },
                    openAbout: { openAbout = true },
                    openHelp: { openHelp = true },
                    logout: viewModel.logout)
        .navigationBarTitle(Text("Settings.Community.Title", bundle: .module))
        .alert(
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
        .onReceive(viewModel.$popToRoot) { shouldDismiss in
            guard shouldDismiss else { return }
            popToRoot = true
        }
        .background(
            Group {
                NavigationLink(destination: SettingProfileView(octopus: viewModel.octopus, popToRoot: $popToRoot,
                                                               preventAutoDismiss: $preventAutoDismiss),
                               isActive: $openProfile) {
                    EmptyView()
                }.hidden()
                NavigationLink(destination: SettingsAboutView(),
                               isActive: $openAbout) {
                    EmptyView()
                }.hidden()
                NavigationLink(destination: SettingsHelpView(),
                               isActive: $openHelp) {
                    EmptyView()
                }.hidden()
            }
        )
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Settings.LogOut.Done.Title", bundle: .module),
                    isPresented: $viewModel.logoutDone, actions: {
                        Button(action: { popToRoot = true }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    })
            } else {
                $0.alert(isPresented: $viewModel.logoutDone) {
                    Alert(title: Text("Settings.LogOut.Done.Title", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        popToRoot = true
                    }))
                }
            }
        }
        .onReceive(Publishers.CombineLatest(viewModel.$logoutInProgress, viewModel.$logoutDone)) {
            preventAutoDismiss = $0.0 || $0.1
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let octopusOwnedProfile: Bool
    let logoutInProgress: Bool
    let openProfile: () -> Void
    let openAbout: () -> Void
    let openHelp: () -> Void
    let logout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)
            theme.colors.gray200
                .frame(height: 1)
            Spacer().frame(height: 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if octopusOwnedProfile {
                        SettingItemView(imageResource: .Settings.account, titleKey: "Settings.Profile",
                                        color: theme.colors.gray600, action: openProfile)
                    }
                    SettingItemView(imageResource: .Settings.info, titleKey: "Settings.About",
                                    color: theme.colors.gray600, action: openAbout)
                    SettingItemView(imageResource: .Settings.help, titleKey: "Settings.Help",
                                    color: theme.colors.gray600, action: openHelp)
                    if octopusOwnedProfile {
                        SettingItemView(imageResource: .Settings.logout, titleKey: "Settings.LogOut.Button",
                                        color: theme.colors.error, isLoading: logoutInProgress, action: logout)
                    }
                }
            }
        }
    }
}

private struct SettingItemView: View {
    @Environment(\.octopusTheme) private var theme

    let imageResource: ImageResource
    let titleKey: LocalizedStringKey
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    init(imageResource: ImageResource, titleKey: LocalizedStringKey, color: Color, isLoading: Bool = false,
         action: @escaping () -> Void) {
        self.imageResource = imageResource
        self.titleKey = titleKey
        self.color = color
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(imageResource)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(color)

                Text(titleKey, bundle: .module)
                    .font(theme.fonts.body2)
                    .fontWeight(.medium)
                    .foregroundColor(color)

                if isLoading {
                    Compat.ProgressView()
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
}
