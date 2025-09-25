//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct OnboardingScreen: View {
    @Environment(\.octopusTheme) private var theme

    let octopus: OctopusSDK
    let manuallyDismissed: () -> Void

    var body: some View {
        NavigationView {
            OnboardingView(octopus: octopus)
                .navigationBarItems(
                    leading:
                        Button(action: manuallyDismissed) {
                            Image(systemName: "xmark")
                                .font(theme.fonts.navBarItem)
                        }
                )
        }
        .presentationBackground(Color(.systemBackground))
        .accentColor(theme.colors.primary)
    }
}

struct OnboardingView: View {
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: OnboardingViewModel

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: OnboardingViewModel(octopus: octopus))
    }

    var body: some View {
        ContentView(
            isLoading: viewModel.isLoading,
            termsOfUseUrl: viewModel.termsOfUse,
            privacyPolicyUrl: viewModel.privacyPolicy,
            communityGuidelinesUrl: viewModel.communityGuidelines,
            continueAction: viewModel.setOnboardingSeenAndCGUAccepted)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let isLoading: Bool
    let termsOfUseUrl: URL
    let privacyPolicyUrl: URL
    let communityGuidelinesUrl: URL
    let continueAction: () -> Void

    private let termsOfUseKey = "TermsOfUse"
    private let privacyPolicyKey = "privacyPolicy"
    private let communityGuidelinesKey = "communityGuidelines"

    var legalTextStr: String {
        if #available(iOS 15, *) {
            return String(
                localized: "Onboarding.Legal_termOfUse:\(termsOfUseUrl.absoluteString)_privacyPolicy:\(privacyPolicyUrl.absoluteString)_communityGuidelines:\(communityGuidelinesUrl.absoluteString)",
                bundle: .module)
        } else {
            return NSLocalizedString(
                "Onboarding.Legal_termOfUse:\(termsOfUseUrl.absoluteString)_privacyPolicy:\(privacyPolicyUrl.absoluteString)_communityGuidelines:\(communityGuidelinesUrl.absoluteString)",
                bundle: .module,
                comment: "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Compat.ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 1)
                    Text("Onboarding.Title", bundle: .module)
                        .font(theme.fonts.title1)
                        .fontWeight(.bold)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                    if theme.assets.logoIsCustomized {
                        Image(uiImage: theme.assets.logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 60)
                    } else {
                        Spacer().frame(height: 5)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        OnboardingTextView(emoji: "🔥", textKey: "Onboarding.Text.Fire")
                        OnboardingTextView(emoji: "💬", textKey: "Onboarding.Text.Talk")
                        OnboardingTextView(emoji: "💡", textKey: "Onboarding.Text.Idea")
                        OnboardingTextView(emoji: "🛡️", textKey: "Onboarding.Text.Shield")
                    }
                    .font(theme.fonts.body1.weight(.medium))
                    .foregroundColor(theme.colors.gray900)
                }
            }

            Spacer().frame(height: 8)

            Button(action: continueAction) {
                Text("Onboarding.Button", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OctopusButtonStyle(.main, enabled: !isLoading))
            .disabled(isLoading)

            Spacer().frame(height: 24)

            RichText(legalTextStr)
                .font(theme.fonts.caption2.weight(.medium))
                .foregroundColor(theme.colors.gray900)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 16)

            PoweredByOctopusView()
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingTextView: View {
    let emoji: String
    let textKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(verbatim: emoji)
            Text(textKey, bundle: .module)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
