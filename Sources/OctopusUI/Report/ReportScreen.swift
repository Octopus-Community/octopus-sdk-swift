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

    var body: some View {
        NavigationView {
            ReportView(octopus: octopus, target: target)
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

    init(octopus: OctopusSDK, target: ReportTarget) {
        let context: ReportViewModel.Context
        switch target {
        case .content(let contentId): context = .content(contentId: contentId)
        case .profile(let profileId): context = .profile(profileId: profileId)
        }
        _viewModel = Compat.StateObject(wrappedValue: ReportViewModel(octopus: octopus, context: context))
    }

    var body: some View {
        ContentView(
            isAboutContent: viewModel.context.isContent,
            moderationInProgress: viewModel.moderationInProgress,
            report: viewModel.report(reasons:)
        )
        .navigationBarTitle(
            Text("Moderation.Common.Title", bundle: .module),
            displayMode: .inline
        )
        .toolbar(leading: cancelButtonBarItem, trailing: EmptyView())
        .emitScreenDisplayed(viewModel.context.isContent ? .reportContent : .reportProfile,
                             trackingApi: trackingApi)
        .errorAlert(viewModel.$error)
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Moderation.Common.Done.Title", bundle: .module),
                    isPresented: $viewModel.moderationSent, actions: {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Text("Common.Ok", bundle: .module)
                        }
                    }, message: {
                        Text("Moderation.Common.Done.Message", bundle: .module)
                    })
            } else {
                $0.alert(isPresented: $viewModel.moderationSent) {
                    Alert(title: Text("Moderation.Common.Done.Title", bundle: .module),
                          message: Text("Moderation.Common.Done.Message", bundle: .module),
                          dismissButton: .default(Text("Common.Ok", bundle: .module), action: {
                        presentationMode.wrappedValue.dismiss()
                    }))
                }
            }
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
                    .foregroundColor(theme.colors.gray900)
            }
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
