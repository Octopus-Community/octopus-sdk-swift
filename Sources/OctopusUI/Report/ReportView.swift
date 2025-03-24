//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct ReportView: View {
    @Environment(\.presentationMode) private var presentationMode

    enum Context {
        case content(contentId: String)
        case profile(profileId: String)

        var isContent: Bool {
            switch self {
            case .content: true
            case .profile: false
            }
        }
    }

    @Compat.StateObject private var viewModel: ReportViewModel
    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK, context: Context) {
        _viewModel = Compat.StateObject(wrappedValue: ReportViewModel(octopus: octopus, context: context))
    }

    var body: some View {
        ContentView(
            isAboutContent: viewModel.context.isContent,
            moderationInProgress: viewModel.moderationInProgress,
            report: viewModel.report(reasons:))
        .navigationBarTitle(
            Text(viewModel.context.isContent ? "Moderation.Content.Title" : "Moderation.Profile.Title",
                 bundle: .module),
            displayMode: .inline)
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
                Spacer().frame(height: 20)
                theme.colors.gray300.frame(height: 1)
                Spacer().frame(height: 20)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(isAboutContent ? "Moderation.Content.Explanation" : "Moderation.Profile.Explanation",
                             bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray500)
                        .multilineTextAlignment(.leading)

                        Spacer().frame(height: 30)

                        VStack(spacing: 16) {
                            ForEach(ReportReason.allCases, id: \.self) {
                                ReasonCell(reason: $0, selectedReasons: $selectedReasons)
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
                Button(action: { report(selectedReasons) }) {
                    Text("Common.Continue", bundle: .module)
                        .foregroundColor(theme.colors.onPrimary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(!selectedReasons.isEmpty ?
                                      theme.colors.primary :
                                        theme.colors.primary.opacity(0.3))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .disabled(selectedReasons.isEmpty || moderationInProgress)
            }
            if moderationInProgress {
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
    }
}

private struct ReasonCell: View {
    @Environment(\.octopusTheme) private var theme

    let reason: ReportReason
    @Binding var selectedReasons: [ReportReason]

    @State private var isOn: Bool = false

    var body: some View {
        Button(action: {
            if selectedReasons.contains(reason) {
                selectedReasons.removeAll { $0 == reason }
            } else {
                selectedReasons.append(reason)
            }
        }) {
            HStack {
                Image(selectedReasons.contains(reason) ? .CheckBox.on : .CheckBox.off)
                reason.displayableString.textView
                    .font(theme.fonts.body2)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundColor(theme.colors.gray900)
        }
        .buttonStyle(.plain)
    }
}
