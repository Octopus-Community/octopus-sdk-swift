//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ReportScreen: View {
    @Environment(\.octopusTheme) private var theme

    let octopus: OctopusSDK
    let target: ReportTarget
    /// Called with the reported profile's id once the user blocked it from the "Report sent" alert and
    /// dismissed the "This user is blocked" alert. Profile reports only: a content report never calls it.
    var onBlocked: (String) -> Void = { _ in }

    var body: some View {
        NavigationView {
            ReportView(octopus: octopus, target: target, onBlocked: onBlocked)
        }
        .navigationViewStyle(.stack)
        .accentColor(theme.colors.primary)
    }
}

private struct ReportView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.trackingApi) private var trackingApi

    @Compat.StateObject private var viewModel: ReportViewModel

    let target: ReportTarget
    let onBlocked: (String) -> Void

    init(octopus: OctopusSDK, target: ReportTarget, onBlocked: @escaping (String) -> Void) {
        self.target = target
        self.onBlocked = onBlocked
        let context: ReportViewModel.Context
        switch target {
        case let .content(contentId, blockableProfileId):
            context = .content(contentId: contentId, blockableProfileId: blockableProfileId)
        case let .profile(profileId, blockableProfileId):
            context = .profile(profileId: profileId, blockableProfileId: blockableProfileId)
        }
        _viewModel = Compat.StateObject(wrappedValue: ReportViewModel(octopus: octopus, context: context))
    }

    var body: some View {
        ContentView(
            isAboutContent: viewModel.context.isContent,
            moderationInProgress: viewModel.moderationInProgress,
            report: viewModel.report(reasons:)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Also covers iOS < 18, where the sheet's `presentationBackground` is not applied.
        .largeScreenMarginBackground()
        .navigationBarTitle(
            Text("Moderation.Common.Title", bundle: .module),
            displayMode: .inline
        )
        .toolbar(leading: cancelButtonBarItem, trailing: EmptyView())
        .emitScreenDisplayed(viewModel.context.isContent ? .reportContent : .reportProfile,
                             trackingApi: trackingApi)
        // Leaving mid-send would drop the error alert, and after a block the screen it closes.
        .modify {
            if #available(iOS 15.0, *) {
                $0.interactiveDismissDisabled(viewModel.moderationInProgress)
            } else { $0 }
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Moderation.Common.Done.Title", bundle: .module),
                    isPresented: $viewModel.moderationSent, actions: {
                        if viewModel.profileIdToBlock != nil {
                            Button(role: .cancel, action: { presentationMode.wrappedValue.dismiss() }) {
                                Text("Common.NotNow", bundle: .module)
                            }
                            Button(role: .destructive, action: viewModel.blockProfile) {
                                Text("Block.Profile.Button", bundle: .module)
                            }
                        } else {
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Text("Common.Ok", bundle: .module)
                            }
                        }
                    }, message: {
                        sentMessage
                    })
            } else {
                $0.alert(isPresented: $viewModel.moderationSent) {
                    if viewModel.profileIdToBlock != nil {
                        Alert(title: Text("Moderation.Common.Done.Title", bundle: .module),
                              message: sentMessage,
                              primaryButton: .cancel(Text("Common.NotNow", bundle: .module), action: {
                            presentationMode.wrappedValue.dismiss()
                        }),
                              secondaryButton: .destructive(Text("Block.Profile.Button", bundle: .module),
                                                            action: viewModel.blockProfile))
                    } else {
                        Alert(title: Text("Moderation.Common.Done.Title", bundle: .module),
                              message: sentMessage,
                              dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                            presentationMode.wrappedValue.dismiss()
                        }))
                    }
                }
            }
        }
        .background(blockDoneAlertAnchor)
        .background(errorAlertAnchor)
    }

    /// The "Report sent" message, followed by the block question when blocking is offered.
    private var sentMessage: Text {
        let message = Text("Moderation.Common.Done.Message", bundle: .module)
        guard viewModel.profileIdToBlock != nil else { return message }
        return message + Text(verbatim: "\n\n") + Text("Moderation.Common.Done.Block.Question", bundle: .module)
    }

    /// The existing "This user is blocked" confirmation, shown once the offered block succeeded. Hosted
    /// on its own view so that it does not compete with the "Report sent" alert on iOS 13 and 14.
    private var blockDoneAlertAnchor: some View {
        Color.clear
            .modify {
                if #available(iOS 15.0, *) {
                    $0.alert(
                        Text("Block.Profile.Done.Title", bundle: .module),
                        isPresented: $viewModel.blockDone, actions: {
                            Button(action: closeAfterBlock) {
                                Text("Common.Ok", bundle: .module)
                            }
                        })
                } else {
                    $0.alert(isPresented: $viewModel.blockDone) {
                        Alert(title: Text("Block.Profile.Done.Title", bundle: .module),
                              dismissButton: .default(Text("Common.Ok", bundle: .module), action: closeAfterBlock))
                    }
                }
            }
    }

    /// The error alert, on its own view for the same reason as `blockDoneAlertAnchor`: a failed block shows it
    /// right after the "Report sent" alert. After a failed block, dismissing it closes the screen.
    private var errorAlertAnchor: some View {
        Color.clear
            .errorAlert(viewModel.$error, onDismiss: {
                guard viewModel.closeAfterError else { return }
                presentationMode.wrappedValue.dismiss()
            })
    }

    /// Closes the report flow. Only a profile report also asks to close the reported profile's screen: after a
    /// content report, the blocked author's content disappears on its own and the screen it was reported from
    /// (the author's profile included) stays open.
    private func closeAfterBlock() {
        presentationMode.wrappedValue.dismiss()
        if case .profile(let profileId, _) = target {
            onBlocked(profileId)
        }
    }

    @ViewBuilder
    private var cancelButtonBarItem: some View {
        if presentationMode.wrappedValue.isPresented {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Common.Cancel", bundle: .module)
                    .font(theme.fonts.navBarItem)
                    .foregroundColor(viewModel.moderationInProgress ? theme.colors.gray500 : theme.colors.gray900)
            }
            .disabled(viewModel.moderationInProgress)
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let isAboutContent: Bool
    let moderationInProgress: Bool
    let report: ([ReportReason]) -> Void

    @State private var selectedReasons: [ReportReason] = []

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Disable nav bar opacity
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(isAboutContent
                             ? "Moderation.Content.Explanation"
                             : "Moderation.Profile.Explanation",
                             bundle: .module)
                            .font(theme.fonts.body1)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.colors.gray900)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 10)

                        Text("Moderation.Common.Caption", bundle: .module)
                            .font(theme.fonts.caption1)
                            .foregroundColor(theme.colors.gray500)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 10)
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            ForEach(ReportReason.allCases, id: \.self) {
                                ReasonCell(reason: $0, selectedReasons: $selectedReasons)
                            }
                        }

                    }
                    .padding(.horizontal, theme.sizes.horizontalPadding)
                }

                Button(action: { report(selectedReasons) }) {
                    Text("Common.Continue", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OctopusButtonStyle(.main,
                                                enabled: !(selectedReasons.isEmpty || moderationInProgress)))
                .padding(.horizontal, theme.sizes.horizontalPadding)
                .padding(.bottom, 16)
                .disabled(selectedReasons.isEmpty || moderationInProgress)
            }

            if moderationInProgress {
                LoadingOverlay()
            }
        }
    }
}

private struct ReasonCell: View {
    @Environment(\.octopusTheme) private var theme

    let reason: ReportReason
    @Binding var selectedReasons: [ReportReason]

    var body: some View {
        Button(action: {
            if selectedReasons.contains(reason) {
                selectedReasons.removeAll { $0 == reason }
            } else {
                selectedReasons.append(reason)
            }
        }) {
            HStack(spacing: 10) {
                IconImage(selectedReasons.contains(reason)
                          ? theme.assets.icons.common.checkbox.on
                          : theme.assets.icons.common.checkbox.off)
                .foregroundColor(selectedReasons.contains(reason) ? theme.colors.primary : theme.colors.gray300)
                reason.displayableString.textView
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .padding(.vertical, 12)
            .frame(minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValueInBundle(selectedReasons.contains(reason)
                                    ? "Accessibility.Common.Selected"
                                    : "Accessibility.Common.NotSelected")
        .modify {
            if #available(iOS 17.0, *) {
                $0.accessibilityAddTraits(.isToggle)
            } else { $0 }
        }
    }
}
