//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus

struct ToastContainer<ContentView: View>: View {
    @EnvironmentObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @ViewBuilder var content: () -> ContentView
    @Compat.StateObject private var viewModel: ToastContainerViewModel

    @State private var showGamificationRules = false

    /// Runs the screen's fetch again, from a retriable error toast's CTA. Screens with nothing to
    /// retry leave it out and their error toasts show no CTA.
    private let retryFailedFetch: (() -> Void)?
    /// How far down the error toasts start. Screens with something floating over their content — the
    /// feed's "explore groups" bar — pass its height so the toast lands under it rather than behind it.
    private let topInset: CGFloat

    init(octopus: OctopusSDK, retryFailedFetch: (() -> Void)? = nil, topInset: CGFloat = 0,
         @ViewBuilder content: @escaping () -> ContentView) {
        _viewModel = Compat.StateObject(wrappedValue: ToastContainerViewModel(octopus: octopus))
        self.retryFailedFetch = retryFailedFetch
        self.topInset = topInset
        self.content = content
    }

    @ViewBuilder
    private func toastView(_ toast: DisplayableToast) -> some View {
        ToastView(
            toast: toast,
            action: {
                switch toast.toast {
                case .gamification:
                    showGamificationRules = true
                case .userAction: break
                case .error: break
                }
            },
            retry: toast.isRetriable ? retryFailedFetch : nil,
            dismiss: {
                withAnimation(.easeInOut) {
                    viewModel.remove(toast)
                }
            })
    }

    var body: some View {
        ZStack {
            content()

            VStack(spacing: 16) {
                // Errors sit at the top of the screen, the rest keeps its place at the bottom.
                ForEach(viewModel.toasts.filter { $0.category == .error }) { toast in
                    toastView(toast)
                }
                Spacer()
                ForEach(viewModel.toasts.filter { $0.category != .error }.reversed()) { toast in
                    toastView(toast)
                }
            }
            .padding(.top, 10 + topInset)
            .padding(.bottom, 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: viewModel.toasts)
            .onAppear {
                viewModel.viewAppeared()
            }
            .onDisappear {
                viewModel.viewDisappeared()
            }
        }
        .gamificationRulesSheet(
            isPresented: $showGamificationRules,
            gamificationConfig: viewModel.gamificationConfig,
            gamificationRulesViewManager: gamificationRulesViewManager)
    }
}

extension View {
    func toastContainer(octopus: OctopusSDK, retryFailedFetch: (() -> Void)? = nil,
                        topInset: CGFloat = 0) -> some View {
        ToastContainer(octopus: octopus, retryFailedFetch: retryFailedFetch, topInset: topInset) { self }
    }
}
