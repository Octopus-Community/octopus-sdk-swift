//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct CreateProfileView: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: CreateProfileViewModel
    @Environment(\.dismissModal) var dismissModal

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: CreateProfileViewModel(octopus: octopus))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ContentView(isLoading: viewModel.isLoading,
                        continueButtonAvailable: viewModel.buttonAvailable,
                        nickname: $viewModel.nickname, birthDate: $viewModel.birthDate,
                        canEditNickname: viewModel.canEditNickname,
                        ageInformation: viewModel.ageInformation,
                        nicknameError: viewModel.nicknameError, birthDateError: viewModel.birthDateError,
                        birthDateFormatter: viewModel.birthDateFormatter,
                        termsOfUseUrl: viewModel.termsOfUse, privacyPolicyUrl: viewModel.privacyPolicy,
                        communityGuidelinesUrl: viewModel.communityGuidelines,
                        createProfile: viewModel.createProfile)
            Button(action: {
                dismissModal.wrappedValue = false
            }) {
                Text("Common.Close", bundle: .module)
            }
            .buttonStyle(.plain)
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in

            }, message: { error in
                error.textView
            })
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            dismissModal.wrappedValue = false
        }
        .onReceive(viewModel.$isLoggedIn) { isLoggedIn in
            guard isLoggedIn else { return }
            dismissModal.wrappedValue = false
        }
        .onReceive(viewModel.$alertError) { displayableError in
            guard let displayableError else { return }
            self.displayableError = displayableError
            displayError = true
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let isLoading: Bool
    let continueButtonAvailable: Bool
    @Binding var nickname: String
    @Binding var birthDate: Date
    let canEditNickname: Bool
    let ageInformation: OctopusCore.ClientUserProfile.AgeInformation?
    let nicknameError: DisplayableString?
    let birthDateError: DisplayableString?
    let birthDateFormatter: DateFormatter
    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL
    let createProfile: () -> Void

    @State private var displayableBirthDate: Date?

    @State private var nicknameFocused = true
    @State private var birthdateFocused = false

    private let termsOfUseKey = "TermsOfUse"
    private let privacyPolicyKey = "privacyPolicy"
    private let communityGuidelinesKey = "communityGuidelines"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Image(uiImage: theme.assets.logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(height: 30)
                    Text("Profile.Create.Title", bundle: .module)
                        .font(theme.fonts.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer().frame(height: 18)

                    OctopusTextInput(
                        text: $nickname, label: "Profile.Create.Nickname.Description",
                        placeholder: "Profile.Nickname.Placeholder",
                        hint: "Profile.Create.Nickname.Explanation",
                        error: nicknameError,
                        isFocused: nicknameFocused,
                        isDisabled: !canEditNickname
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($nicknameFocused)
                    .disabled(!canEditNickname)
                    .modify {
                        if #available(iOS 15.0, *) {
                            $0.submitLabel(.next)
                        } else {
                            $0
                        }
                    }

                    Spacer().frame(minHeight: 10, idealHeight: 22, maxHeight: 22)

                    switch ageInformation {
                    case .legalAgeReached:
                        EmptyView()
                    case .underaged:
                        Text("Profile.Create.BirthDate.Underaged", bundle: .module)
                            .font(theme.fonts.caption2)
                            .fontWeight(.regular)
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                    case .none:
                        OctopusInput(
                            label: "Profile.Create.BirthDate.Description",
                            hint: "Profile.Create.BirthDate.Explanation",
                            error: birthDateError,
                            isFocused: birthdateFocused) {
                                DateTextField(date: $birthDate,
                                              text: displayableBirthDate.map { birthDateFormatter.string(from: $0) } ?? " ",
                                              doneAction: { birthdateFocused = false })
                                .placeholder(when: displayableBirthDate == nil) {
                                    Text("Profile.Create.BirthDate.Placeholder", bundle: .module)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(theme.colors.gray500)
                                }
                            }
                            .focused($birthdateFocused)
                    }

                    Spacer().frame(height: 30)

                    if #available(iOS 15.0, *) {
                        let string = String(
                            localized: "Profile.Create.Legal_termOfUse:\(termsOfUseKey)_privacyPolicy:\(privacyPolicyKey)_communityGuidelines:\(communityGuidelinesKey)",
                            bundle: .module)
                        if let attrStr = try? AttributedString(markdown: string) {
                            Text(attrStr)
                                .font(theme.fonts.caption1)
                                .foregroundColor(theme.colors.gray700)
                                .tint(theme.colors.link)
                                .environment(\.openURL, OpenURLAction { url in
                                    if url.host == termsOfUseKey {
                                        UIApplication.shared.open(termsOfUseUrl)
                                    } else if url.host == privacyPolicyKey {
                                        UIApplication.shared.open(privacyPolicyUrl)
                                    } else if url.host == communityGuidelinesKey {
                                        UIApplication.shared.open(communityGuidelinesUrl)
                                    }
                                    return .handled
                                })
                        }
                    } else {
                        Compat.Link(destination: communityGuidelinesUrl) {
                            Text("Profile.Create.Legal", bundle: .module)
                                .font(theme.fonts.caption1)
                                .foregroundColor(theme.colors.gray700)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            .modify {
                if #available(iOS 16.0, *) {
                    $0.scrollDismissesKeyboard(.automatic)
                } else {
                    $0
                }
            }
            Spacer()
            if !isLoading {
                Button(action: createProfile) {
                    Text("Profile.Create.Button", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OctopusButtonStyle(.main, enabled: continueButtonAvailable))
                .disabled(!continueButtonAvailable)
            } else {
                HStack {
                    Spacer()
                    Compat.ProgressView()
                        .frame(width: 60)
                    Spacer()
                }
            }
            Spacer().frame(height: 8)

            if !((nicknameFocused && canEditNickname) || birthdateFocused) {
                Spacer().frame(height: 6)
                theme.colors.gray300.frame(height: 1)
                Spacer().frame(height: 10)

                PoweredByOctopusView()
            }
        }
        .padding(.top)
        .padding(.horizontal, 20)
        .onValueChanged(of: birthDate) {
            displayableBirthDate = $0
        }
    }
}

//#Preview {
//    ContentView(state: .emailEntry(.emailNeeded), sendEmailButtonAvailable: true, email: .constant(""),
//                sendMagicLink: { }, enterNewEmail: { }, checkMagicLinkConfirmed: { })
//}
