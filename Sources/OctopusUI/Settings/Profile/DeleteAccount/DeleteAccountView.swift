//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

struct DeleteAccountView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Compat.StateObject private var viewModel: DeleteAccountViewModel
    @Environment(\.octopusTheme) private var theme

    @State private var displayDeleteUserAlert = false

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var selectedReason: DeleteAccountReason?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        _viewModel = Compat.StateObject(wrappedValue: DeleteAccountViewModel(
            octopus: octopus, mainFlowPath: mainFlowPath))
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)
                theme.colors.gray300.frame(height: 1)
                Spacer().frame(height: 20)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(.Settings.warning)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(theme.colors.error)

                            Text("Settings.Profile.DeleteAccount.MainText", bundle: .module)
                                .font(theme.fonts.body2)
                                .fontWeight(.medium)
                                .foregroundColor(theme.colors.error)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }

                        Spacer().frame(height: 20)

                        Text("Settings.Profile.DeleteAccount.Farewell",
                             bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray500)
                        .multilineTextAlignment(.leading)

                        Spacer().frame(height: 30)

                        VStack(spacing: 16) {
                            ForEach(DeleteAccountReason.allCases, id: \.self) {
                                ReasonCell(reason: $0, selectedReason: $selectedReason)
                            }
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.colors.gray300, lineWidth: 1)
                        )

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                }
                Button(action: { displayDeleteUserAlert = true }) {
                    Text("Common.Continue", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(selectedReason != nil ? theme.colors.onPrimary : theme.colors.disabled)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(selectedReason != nil ? theme.colors.primary : theme.colors.gray300)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .disabled(selectedReason == nil || viewModel.deleteAccountInProgress)
            }
            if viewModel.deleteAccountInProgress {
                Compat.ProgressView()
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerSize: CGSize(width: 4, height: 4))
                            .modify {
                                if #available(iOS 15.0, *) {
                                    $0.fill(.thickMaterial)
                                } else {
                                    $0.fill(theme.colors.gray200)
                                }
                            }
                    )
            }
        }
        .navigationBarTitle(Text("Settings.Profile.DeleteAccount.Title", bundle: .module), displayMode: .inline)
        .alert(isPresented: $displayDeleteUserAlert) {
            Alert(
                title: Text("Settings.Profile.DeleteAccount.Confirmation.Title", bundle: .module),
                message: Text("Settings.Profile.DeleteAccount.Confirmation.Message",
                              bundle: .module),
                primaryButton: .destructive(Text("Settings.Profile.DeleteAccount.Confirmation.Delete", bundle: .module)) {
                    guard let selectedReason else { return }
                    viewModel.deleteAccount(reason: selectedReason)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in

            }, message: { error in
                error.textView
            })
        .onReceive(viewModel.$error) { displayableError in
            guard let displayableError else { return }
            self.displayableError = displayableError
            displayError = true
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Settings.Profile.DeleteAccount.Done.Title", bundle: .module),
                    isPresented: $viewModel.accountDeleted, actions: {
                        Button(action: { navigator.popToRoot() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    }, message: {
                        Text("Settings.Profile.DeleteAccount.Done.Message_contactEmail:\(viewModel.email)", bundle: .module)
                    })
            } else {
                $0.alert(isPresented: $viewModel.accountDeleted) {
                    Alert(title: Text("Settings.Profile.DeleteAccount.Done.Title", bundle: .module),
                          message: Text("Settings.Profile.DeleteAccount.Done.Message_contactEmail:\(viewModel.email)", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        navigator.popToRoot()
                    }))
                }
            }
        }
    }
}

private struct ReasonCell: View {
    @Environment(\.octopusTheme) private var theme

    let reason: DeleteAccountReason
    @Binding var selectedReason: DeleteAccountReason?

    @State private var isOn: Bool = false

    var body: some View {
        Button(action: {
            guard selectedReason != reason else { return }
            selectedReason = reason
        }) {
            HStack {
                Image(selectedReason == reason ? .RadioButton.on : .RadioButton.off)
                Text(reason.localizedKey, bundle: .module)
                    .font(theme.fonts.body2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundColor(theme.colors.gray900)
        }
        .buttonStyle(.plain)
    }
}

extension DeleteAccountReason {
    var localizedKey: LocalizedStringKey {
        return switch self {
        case .noMoreInterested: "Settings.Profile.DeleteAccount.Reason.NoMoreInterested"
        case .missingKeyFeatures: "Settings.Profile.DeleteAccount.Reason.MissingKeyFeatures"
        case .technicalIssues: "Settings.Profile.DeleteAccount.Reason.TechnicalIssues"
        case .confidentialityWorrying: "Settings.Profile.DeleteAccount.Reason.ConfidentialityWorrying"
        case .communityQuality: "Settings.Profile.DeleteAccount.Reason.CommunityQuality"
        case .reducingSnTime: "Settings.Profile.DeleteAccount.Reason.ReducingSnTime"
        case .other: "Settings.Profile.DeleteAccount.Reason.Other"
        }
    }
}
