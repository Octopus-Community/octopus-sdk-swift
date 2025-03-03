//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

enum PostListRoute: Equatable {
    case currentUserProfile
}

struct PostListViewRouter: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: PostListViewRouterModel

    @Binding var loggedInDone: Bool
    @Binding var openRoute: PostListRoute?

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var openCurrentUserProfile = false

    init(octopus: OctopusSDK, openRoute: Binding<PostListRoute?>, loggedInDone: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: PostListViewRouterModel(octopus: octopus))
        _openRoute = openRoute
        _loggedInDone = loggedInDone
    }

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    NavigationLink(destination: CurrentUserProfileSummaryView(octopus: viewModel.octopus,
                                                                              dismiss: !$openCurrentUserProfile),
                                   isActive: $openCurrentUserProfile) {
                        EmptyView()
                    }.hidden()
                })
            .connectionRouter(viewModel: viewModel.connectionRouterViewModel, loggedInDone: $loggedInDone)
            .onValueChanged(of: openRoute) {
                defer { openRoute = nil }
                switch $0 {
                case .currentUserProfile:
                    guard viewModel.connectionRouterViewModel.ensureConnected() else { return }
                    openCurrentUserProfile = true
                case .none: break
                }
            }
    }
}

extension View {
    func postListViewRouter(octopus: OctopusSDK, openRoute: Binding<PostListRoute?>, loggedInDone: Binding<Bool>) -> some View {
        modifier(PostListViewRouter(octopus: octopus, openRoute: openRoute, loggedInDone: loggedInDone))
    }
}

@MainActor
private class PostListViewRouterModel: ObservableObject {
    let connectionRouterViewModel: ConnectionRouterViewModel

    let octopus: OctopusSDK
    init(octopus: OctopusSDK) {
        self.octopus = octopus
        connectionRouterViewModel = ConnectionRouterViewModel(octopus: octopus)
    }
}

