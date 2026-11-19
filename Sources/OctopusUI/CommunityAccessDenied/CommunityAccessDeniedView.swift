//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct CommunityAccessDeniedView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme
    @Environment(\.trackingApi) private var trackingApi
    @Environment(\.urlOpener) private var urlOpener
    @EnvironmentObject private var languageManager: LanguageManager

    @Compat.StateObject private var viewModel: CommunityAccessDeniedViewModel
    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    /// The policy displayed in the sheet, `nil` when the sheet is closed.
    @State private var displayedPolicy: DisplayedPolicy?

    init(octopus: OctopusSDK, canClose: Bool, navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        _viewModel = Compat.StateObject(wrappedValue: CommunityAccessDeniedViewModel(octopus: octopus))
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        ContentView(content: viewModel.content, locale: languageManager.overridenLocale,
                    isActionRunning: viewModel.isReturning, onAction: onAction, openMail: { urlOpener.open(url: $0) })
            .emitScreenDisplayed(.communityAccessDenied, trackingApi: trackingApi)
            .errorAlert(viewModel.$error)
            .octopusSheet(item: $displayedPolicy) { policy in
                CommunityAccessDeniedPolicyView(policyName: policy.name, policyDescription: policy.description)
                    .sizedSheet()
            }
            .onValueChanged(of: viewModel.content?.action) { action in
                // The policy only stands while the account is banned
                if case .knowMore = action { return }
                displayedPolicy = nil
            }
            .modify {
                if let navBarLeadingAction {
                    $0.navigationBarItems(leading: NavBarLeadingActionButton(navBarLeadingAction))
                } else if canClose {
                    $0.navigationBarItems(
                        leading:
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                IconImage(theme.assets.icons.common.close)
                                    .font(theme.fonts.navBarItem)
                                    .accessibilityLabelInBundle("Common.Close")
                            }
                    )
                } else {
                    $0
                }
            }
    }
}

extension CommunityAccessDeniedView {
    private func onAction() {
        switch viewModel.content?.action {
        case let .knowMore(policyName, policyDescription):
            displayedPolicy = DisplayedPolicy(name: policyName, description: policyDescription)
        case .accessCommunity:
            viewModel.accessCommunity()
        case nil:
            break
        }
    }
}

/// The policy a banned account broke, as the sheet displays it.
private struct DisplayedPolicy: Identifiable {
    let name: String
    let description: String

    var id: String { name }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.textTone) private var textTone

    /// Nothing is displayed until the reason is known.
    let content: CommunityAccessDeniedContent?
    /// The language the host app forces, `nil` to follow the system.
    let locale: Locale?
    let isActionRunning: Bool
    let onAction: () -> Void
    let openMail: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The texts scroll when they do not fit (large text sizes), the footer stays at the bottom
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        if let content {
                            CommunityAccessDeniedIcon()
                                .padding(.vertical, 4)
                            content.title.textView(tone: textTone)
                                .font(theme.fonts.title2)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)
                                .modifier(CenteredText())
                            SubtitleView(subtitle: content.subtitle, locale: locale, openMail: openMail)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }

            VStack(spacing: 24) {
                switch content?.action {
                case .knowMore:
                    Button(action: onAction) {
                        Text("CommunityAccessDenied.Banned.KnowMore", bundle: .module)
                            .frame(minHeight: 28)
                    }
                    .buttonStyle(OctopusButtonStyle(.mid, style: .secondary,
                                                    backgroundColor: theme.colors.gray200))
                case .accessCommunity:
                    Button(action: onAction) {
                        // The label keeps its place while the return runs, so that the button keeps its size
                        Text("CommunityAccessDenied.Deleted.AccessCommunity", bundle: .module)
                            .frame(minHeight: 28)
                            .opacity(isActionRunning ? 0 : 1)
                            .overlay(Group {
                                if isActionRunning {
                                    Compat.ProgressView()
                                }
                            })
                    }
                    .buttonStyle(OctopusButtonStyle(.mid, style: .secondary,
                                                    backgroundColor: theme.colors.gray200))
                    .disabled(isActionRunning)
                case nil:
                    EmptyView()
                }
                PoweredByOctopusView()
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .largeScreenMarginBackground()
    }
}

private struct SubtitleView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.textTone) private var textTone

    let subtitle: CommunityAccessDeniedContent.Subtitle?
    let locale: Locale?
    let openMail: (URL) -> Void

    var body: some View {
        switch subtitle {
        case let .message(message):
            // The message of the server is displayed as it is: it is not a key, nor markdown
            Text(verbatim: message)
                .font(theme.fonts.body2)
                .modifier(CenteredText())
        case let .ban(ban):
            Group {
                if let nickname = ban.nickname {
                    Text(textTone.key(
                        formal: "CommunityAccessDenied.Banned.Text.Formal_nickname:\(nickname)_policyName:\(ban.policyName)",
                        informal: "CommunityAccessDenied.Banned.Text.Informal_nickname:\(nickname)_policyName:\(ban.policyName)"),
                         bundle: .module)
                } else {
                    Text(textTone.key(
                        formal: "CommunityAccessDenied.Banned.TextWithoutNickname.Formal_policyName:\(ban.policyName)",
                        informal: "CommunityAccessDenied.Banned.TextWithoutNickname.Informal_policyName:\(ban.policyName)"),
                         bundle: .module)
                }
            }
            .font(theme.fonts.body2)
            .modifier(CenteredText())
            if let contactEmail = ban.contactEmail {
                BanAppealView(contactEmail: contactEmail, locale: locale, openMail: openMail)
            }
        case nil:
            EmptyView()
        }
    }
}

/// Who a banned member can write to, in a paragraph of its own: the address is underlined and opens a mail.
private struct BanAppealView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.textTone) private var textTone

    let contactEmail: String
    let locale: Locale?
    let openMail: (URL) -> Void

    var body: some View {
        if let url = CommunityAccessDeniedBanAppeal.mailtoURL(for: contactEmail) {
            // The whole paragraph is the tap target
            Button(action: { openMail(url) }) {
                sentence
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isLink)
        } else {
            sentence
        }
    }

    private var sentence: some View {
        let parts = CommunityAccessDeniedBanAppeal.parts(
            sentence: L10n(textTone.stringKey(formal: "CommunityAccessDenied.Banned.Appeal.Formal_contactEmail:%@",
                                              informal: "CommunityAccessDenied.Banned.Appeal.Informal_contactEmail:%@"),
                           locale: locale, contactEmail),
            email: contactEmail)
        return (Text(verbatim: parts.before) + Text(verbatim: parts.email).underline() + Text(verbatim: parts.after))
            .font(theme.fonts.body2)
            .modifier(CenteredText())
    }
}

/// A text of the screen: centered, on as many lines as it needs.
private struct CenteredText: ViewModifier {
    @Environment(\.octopusTheme) private var theme

    func body(content: Content) -> some View {
        content
            .foregroundColor(theme.colors.gray900)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

#Preview("Cohort") {
    ContentView(content: .init(reason: .cohort, message: "The community will be available soon."),
                locale: nil, isActionRunning: false, onAction: { }, openMail: { _ in })
}

#Preview("No message") {
    ContentView(content: .init(reason: .closed, message: nil),
                locale: nil, isActionRunning: false, onAction: { }, openMail: { _ in })
}

#Preview("Banned") {
    ContentView(
        content: .init(
            reason: .accountBanned(.init(nickname: "marie_l92", policyName: "Job applications",
                                         policyDescription: "No job offers here.",
                                         contactEmail: "community-support@yourbrandname.com")),
            message: nil),
        locale: nil, isActionRunning: false, onAction: { }, openMail: { _ in })
}

#Preview("Deleted, returning") {
    ContentView(content: .init(reason: .accountDeleted, message: nil),
                locale: nil, isActionRunning: true, onAction: { }, openMail: { _ in })
}

#Preview("Deleted") {
    ContentView(content: .init(reason: .accountDeleted, message: "You can still browse the community as a visitor."),
                locale: nil, isActionRunning: false, onAction: { }, openMail: { _ in })
}
