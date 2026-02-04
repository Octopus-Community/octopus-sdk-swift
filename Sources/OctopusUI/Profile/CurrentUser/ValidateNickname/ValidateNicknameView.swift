//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ValidateNicknameScreen: View {
    @Environment(\.octopusTheme) private var theme

    let octopus: OctopusSDK
    @Binding var isPresented: Bool

    @State private var flowPath = ValidateNicknameFlowPath()

    var body: some View {
        ValidateNicknameFlowNavigationStack(octopus: octopus, flowPath: flowPath) {
            ValidateNicknameView(octopus: octopus, isPresented: $isPresented)
        }
        .presentationBackground(Color(.systemBackground))
        .accentColor(theme.colors.primary)
    }
}

struct ValidateNicknameView: View {
    @EnvironmentObject var navigator: Navigator<ValidateNicknameFlowScreen>
    @EnvironmentObject var trackingApi: TrackingApi

    @Compat.StateObject private var viewModel: ValidateNicknameViewModel
    @Binding var isPresented: Bool

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK, isPresented: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: ValidateNicknameViewModel(octopus: octopus))
        _isPresented = isPresented
    }

    var body: some View {
        ContentView(
            nickname: viewModel.nickname,
            isLoading: viewModel.isLoading,
            editProfile: { navigator.push(.editProfile) },
            setNicknameAsConfirmed: viewModel.setNicknameAsConfirmed)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in
                Button(action: {}) {
                    Text("Common.Cancel", bundle: .module)
                }
                Button(action: { isPresented = false }) {
                    Text("Common.Close", bundle: .module)
                }
            },
            message: { error in
                error.textView
            })
        .emitScreenDisplayed(.validateNickname, trackingApi: trackingApi)
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            isPresented = false
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    
    let nickname: String
    let isLoading: Bool
    let editProfile: () -> Void
    let setNicknameAsConfirmed: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Compat.ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    Text("ValidateNickname.Title", bundle: .module)
                        .font(theme.fonts.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                    
                    Spacer().frame(height: 24)

                    Image(res: .congrats)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 144)
                        .accessibilityHidden(true)

                    Spacer().frame(height: 18)

                    Text("ValidateNickname.Nickname", bundle: .module)
                        .font(theme.fonts.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                    
                    Spacer().frame(height: 8)
                    
                    Text(nickname)
                        .font(theme.fonts.title1)
                        .fontWeight(.bold)
                        .minimumScaleFactor(0.2)
                        .foregroundColor(theme.colors.gray900)
                        .lineLimit(1)
                    
                    Spacer().frame(height: 16)
                    
                    Text("ValidateNickname.Modification", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer().frame(height: 16)

            Button(action: editProfile) {
                Text("ValidateNickname.Action.Modify", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OctopusButtonStyle(.main))

            Spacer().frame(height: 8)

            Button(action: setNicknameAsConfirmed) {
                Text("ValidateNickname.Action.Later", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OctopusButtonStyle(.main, style: .outline))

            Spacer().frame(height: 16)

            PoweredByOctopusView()
        }
        .padding(.horizontal, 16)
    }
}
