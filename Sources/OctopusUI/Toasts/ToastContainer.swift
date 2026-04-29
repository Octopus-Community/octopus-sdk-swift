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

    init(octopus: OctopusSDK, @ViewBuilder content: @escaping () -> ContentView) {
        _viewModel = Compat.StateObject(wrappedValue: ToastContainerViewModel(octopus: octopus))
        self.content = content
    }

    var body: some View {
        ZStack {
            content()

            VStack(spacing: 16) {
                Spacer()
                ForEach(viewModel.toasts.reversed()) { toast in
                    ToastView(
                        toast: toast,
                        action: {
                            switch toast.toast {
                            case .gamification:
                                showGamificationRules = true
                            case .userAction: break
                            case .error: break
                            }
                        }, dismiss: {
                            withAnimation(.easeInOut) {
                                viewModel.remove(toast)
                            }
                        })
                }
            }
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
    func toastContainer(octopus: OctopusSDK) -> some View {
        ToastContainer(octopus: octopus) { self }
    }
}
