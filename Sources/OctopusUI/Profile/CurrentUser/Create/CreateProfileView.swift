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

    @Binding var isLoggedIn: Bool

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK, isLoggedIn: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: CreateProfileViewModel(octopus: octopus))
        _isLoggedIn = isLoggedIn
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
                        communityGuidelinesUrl: viewModel.communityGuidelines, contactUsUrl: viewModel.contactUs,
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
        .alert(
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
            self.isLoggedIn = true
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
    let contactUsUrl: URL
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

                    Text("Profile.Create.Nickname.Description", bundle: .module)
                        .font(theme.fonts.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.gray700)
                        .multilineTextAlignment(.leading)

                    Spacer().frame(height: 10)

                    TextField(L10n("Profile.Nickname.Placeholder"), text: $nickname) {
                        birthdateFocused = true
                    }
                    .font(theme.fonts.body2)
                    .foregroundColor(theme.colors.gray900)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .modify {
                        if #available(iOS 15.0, *) {
                            $0.submitLabel(.next)
                        } else {
                            $0
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .focused($nicknameFocused)
                    .background(canEditNickname ? Color.clear : theme.colors.gray300)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(nicknameFocused && canEditNickname ? theme.colors.gray900 : theme.colors.gray300,
                                    lineWidth: nicknameFocused && canEditNickname ? 2 : 1)
                    )
                    .disabled(!canEditNickname)
                    .padding(.horizontal, 2)
                    Spacer().frame(height: 6)
                    Text("Profile.Create.Nickname.Explanation", bundle: .module)
                        .font(theme.fonts.caption2)
                        .foregroundColor(theme.colors.gray700)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let nicknameError {
                        Spacer().frame(height: 4)
                        nicknameError.textView
                            .font(theme.fonts.caption2)
                            .bold()
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer().frame(minHeight: 10, idealHeight: 22, maxHeight: 22)

                    switch ageInformation {
                    case .legalAgeReached:
                        EmptyView()
                    case .underaged:
                        Text("Profile.Create.BirthDate.Underaged", bundle: .module)
                            .font(theme.fonts.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.leading)
                    case .none:
                        Text("Profile.Create.BirthDate.Description", bundle: .module)
                            .font(theme.fonts.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.colors.gray900)
                            .multilineTextAlignment(.leading)

                        Spacer().frame(height: 10)

                        DateTextField(date: $birthDate,
                                      text: displayableBirthDate.map { birthDateFormatter.string(from: $0) } ?? " ",
                                      doneAction: { birthdateFocused = false })
                        .focused($birthdateFocused)
                        .placeholder(when: displayableBirthDate == nil) {
                            Text("Profile.Create.BirthDate.Placeholder", bundle: .module)
                                .multilineTextAlignment(.leading)
                                .foregroundColor(theme.colors.gray500)
                        }
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(birthdateFocused ? theme.colors.gray900 : theme.colors.gray300,
                                        lineWidth: birthdateFocused ? 2 : 1)

                        )
                        .padding(.horizontal, 2)

                        Spacer().frame(height: 6)
                        Text("Profile.Create.BirthDate.Explanation", bundle: .module)
                            .font(theme.fonts.caption2)
                            .foregroundColor(theme.colors.gray700)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let birthDateError {
                            Spacer().frame(height: 4)
                            birthDateError.textView
                                .font(theme.fonts.caption2)
                                .bold()
                                .foregroundColor(theme.colors.error)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
                        .foregroundColor(theme.colors.onPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(continueButtonAvailable ?
                                      theme.colors.primary :
                                        theme.colors.primary.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!continueButtonAvailable)
            } else {
                Compat.ProgressView()
                    .frame(width: 60)
            }
            Spacer().frame(height: 8)

            if #available(iOS 15.0, *) {
                Text("Profile.Create.ContactUs.Link", bundle: .module)
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.gray700)
                    .tint(theme.colors.link)
                    .environment(\.openURL, OpenURLAction { url in
                        UIApplication.shared.open(contactUsUrl)
                        return .handled
                    })
            } else {
                Compat.Link(destination: contactUsUrl) {
                    Text("Profile.Create.ContactUs.NoLink", bundle: .module)
                        .font(theme.fonts.caption1)
                        .foregroundColor(theme.colors.gray700)
                        .multilineTextAlignment(.leading)
                }
            }
            if !(nicknameFocused || birthdateFocused) {
                Spacer().frame(height: 6)
                theme.colors.gray300.frame(height: 1)
                Spacer().frame(height: 10)

                HStack {
                    Image(.octopusLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 17, height: 16)
                    Text("Common.PoweredByOctopus", bundle: .module)
                        .font(theme.fonts.caption2)
                        .foregroundColor(theme.colors.gray700)
                }.frame(maxWidth: .infinity)
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
