//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// The first-start Configuration, internal demo mode only: Start SDK persists the config, which makes
/// `SampleRootView` swap this screen for the tabs. After Settings › Reset the SDK of the previous setup is still
/// alive, and Start SDK rebuilds it on the new config, as Apply does.
struct SDKConfigScreen: View {
    var body: some View {
        NavigationView {
            ConfigView(isRevisit: false)
                .hostAppFooter(debugConsole: false)
        }
        .navigationViewStyle(.stack)
    }
}

struct SDKConfigView: View {
    let afterSaveAction: () -> Void

    @StateObjectCompat private var viewModel = SDKConfigViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SampleTokens.Spacing.space4) {
                card(systemImage: "person.text.rectangle", title: "Associated Fields") {
                    Toggle(isOn: $viewModel.nicknameIsAssociated) {
                        Text("Nickname")
                    }
                    Toggle(isOn: $viewModel.bioIsAssociated) {
                        Text("Bio")
                    }
                    Toggle(isOn: $viewModel.pictureIsAssociated) {
                        Text("Picture")
                    }
                }

                if !viewModel.nicknameIsAssociated {
                    card(systemImage: "lock.shield", title: "Security") {
                        Toggle(isOn: $viewModel.forceLoginOnStringAction) {
                            Text("Force login on strong actions")
                        }
                    }
                }

                unifiedProfileCard

                card(systemImage: "wifi.slash", title: "Debug") {
                    Toggle(isOn: Binding(get: { viewModel.forceOffline },
                                         set: { viewModel.setForceOffline($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Act as if offline")
                            // A simulator always reports a connection, so the offline states are out
                            // of reach there without this.
                            caption("Reaches the empty / error screen states and the no-connection " +
                                    "toast without a device in airplane mode.")
                        }
                    }
                    .accessibilityId("qa-config-forceOffline")
                }

                if viewModel.canSave {
                    Button(action: {
                        viewModel.save()
                        afterSaveAction()
                    }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Save")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(SampleTokens.Colors.buttonBackground))
                        .foregroundColor(SampleTokens.Colors.buttonText)
                    }
                } else {
                    Text("No existing community to match this configuration")
                        .font(.subheadline)
                        .foregroundColor(SampleTokens.Colors.danger)
                }
            }
            .padding()
        }
        .navigationBarTitle(Text("SDK Configuration"))
        .sampleScreenBackground()
    }

    /// Both host-side inputs of Unified Profile behind one switch, and the line saying what a profile tap does
    /// right now. Applied at once, like the offline switch: it is a host integration choice, not part of the
    /// SDK config the Save button rebuilds the SDK on.
    private var unifiedProfileCard: some View {
        card(systemImage: "person.crop.circle.badge.checkmark", title: "Unified profile") {
            Toggle(isOn: Binding(get: { viewModel.unifiedProfile.isSwitchOn },
                                 set: { viewModel.setUnifiedProfileEnabled($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open the app's profile")
                    caption("Wires onNavigateToProfile and forces the community's exposeClientUserId flag on. " +
                            "Off unwires the callback and goes back to the backend flag.")
                }
            }
            .accessibilityId("config-unified-profile")

            Text(viewModel.unifiedProfile.statusLine)
                .font(.footnote)
                .foregroundColor(SampleTokens.Colors.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityId("config-unified-profile-status")
        }
    }

    private func card(systemImage: String, title: String,
                      @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(SampleTokens.Colors.accentText)
                Text(title)
                    .font(.subheadline).bold()
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .sampleCardSurface()
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(SampleTokens.Colors.textSecondary)
    }
}
