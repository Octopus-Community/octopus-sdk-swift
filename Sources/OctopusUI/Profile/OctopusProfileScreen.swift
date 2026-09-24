//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// UI Entry point to open an Octopus profile directly, without going through `OctopusHomeScreen`.
///
/// This SwiftUI view contains a NavigationView, hence it should be not embedded in another Navigation object.
public struct OctopusProfileScreen: View {

    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    private let octopus: OctopusSDK
    private let navigationMode: OctopusNavigationMode
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    @Compat.StateObject private var viewModel: OctopusProfileScreenViewModel
    @Compat.StateObject private var translationStore: ContentTranslationPreferenceStore
    @State private var trackingApi: DefaultTrackingApi
    @Compat.StateObject private var gamificationRulesViewManager: GamificationRulesViewManager
    @Compat.StateObject private var displayConfigManager: DisplayConfigManager
    @Compat.StateObject private var reactionsListManager: ReactionsListManager
    @Compat.StateObject private var videoManager: VideoManager
    @State private var urlOpener: URLOpener
    @Compat.StateObject private var languageManager: LanguageManager

    /// Constructor of the `OctopusProfileScreen`.
    /// - Parameters:
    ///    - octopus: The Octopus SDK
    ///    - clientUserId: the host app's own id (as passed to `ConnectionMode.sso`) for the member whose
    ///                    profile to display. Default is `nil`, which displays the connected user's own
    ///                    profile. When set, the profile is resolved via the community's dedicated
    ///                    clientUserId lookup; if it cannot be resolved (unknown id, the community does not
    ///                    expose client user ids, or a network failure), a generic error state is shown —
    ///                    the screen never falls back to displaying the connected user's own profile.
    ///    - navigationMode: which navigation container the screen uses internally. Default is
    ///                      `.navigationStack`, unlike `OctopusHomeScreen` (which defaults to `.automatic`
    ///                      to preserve behavior for hosts integrated before `.navigationStack` existed).
    ///                      `OctopusProfileScreen` is a new type with no prior integrations to preserve, and
    ///                      its own contract explicitly promotes modal presentation (`.fullScreenCover`),
    ///                      exactly where the legacy `NavigationView` behind `.automatic` can silently drop
    ///                      in-app pushes. Pass `.automatic` to opt back into the legacy container if you
    ///                      have a specific reason to. See `OctopusNavigationMode`.
    ///    - navBarLeadingAction: an optional host-driven leading nav-bar item displayed on the profile screen.
    ///                           Use it when you host `OctopusProfileScreen` somewhere the SDK cannot dismiss
    ///                           itself (pushed on your own navigation stack, or mounted by a Flutter / React
    ///                           Native plugin): the SDK's built-in close button only appears when the view is
    ///                           presented natively (`.sheet` / `.fullScreenCover`). Pass `.close(onTap:)` or
    ///                           `.back(onTap:)` to show the corresponding item and be told when it is tapped —
    ///                           the closure runs instead of dismissing a SwiftUI presentation. Default is nil.
    ///
    /// You can pass an OctopusTheme as an environment to customize the colors, fonts and images used in this
    /// view:
    /// ```swift
    /// OctopusProfileScreen(octopus: octopus)
    ///     .environment(\.octopusTheme, appTheme)
    /// ```
    public init(octopus: OctopusSDK, clientUserId: String? = nil,
                navigationMode: OctopusNavigationMode = .navigationStack,
                navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        self.octopus = octopus
        self.navigationMode = navigationMode
        self.navBarLeadingAction = navBarLeadingAction
        _viewModel = Compat.StateObject(
            wrappedValue: OctopusProfileScreenViewModel(octopus: octopus, clientUserId: clientUserId))
        _translationStore = Compat.StateObject(wrappedValue: ContentTranslationPreferenceStore(
            repository: octopus.core.contentTranslationPreferenceRepository))
        _trackingApi = State(wrappedValue: DefaultTrackingApi(octopus: octopus))
        _gamificationRulesViewManager = Compat.StateObject(wrappedValue: GamificationRulesViewManager(octopus: octopus))
        _displayConfigManager = Compat.StateObject(wrappedValue: DisplayConfigManager(octopus: octopus))
        _reactionsListManager = Compat.StateObject(wrappedValue: ReactionsListManager(octopus: octopus))
        _videoManager = Compat.StateObject(wrappedValue: VideoManager(octopus: octopus))
        _urlOpener = State(wrappedValue: URLOpener(octopus: octopus))
        _languageManager = Compat.StateObject(wrappedValue: LanguageManager(octopus: octopus))
    }

    public var body: some View {
        MainFlowNavigationStack(octopus: octopus, mainFlowPath: viewModel.mainFlowPath,
                                navigationMode: navigationMode) {
            if #available(iOS 14.0, *) {
                content
                    .insetableMainNavigationView(bottomSafeAreaInset: 0)
            } else {
                UnsupportedOSVersionView()
            }
        }
        .modify {
            // do not use presentationBackground on iOS 17 because it breaks the layout when the view is presented
            if #available(iOS 18.0, *) {
                // Community background, like OctopusHomeScreen does (was hardcoded to the system one).
                $0.presentationBackground(theme.colors.background)
            } else {
                $0
            }
        }
        .accentColor(theme.colors.primary)
        .navigationViewStyle(.stack)
        .onAppear {
            octopus.core.toastsRepository.resetDisplayedToasts()
            octopus.core.trackingRepository.octopusUISessionStarted()
            gamificationRulesViewManager.setHomeScreenVisible(true)
            gamificationRulesViewManager.incrementViewCountIfNeeded()
        }
        .onDisappear {
            octopus.core.toastsRepository.resetDisplayedToasts()
            octopus.core.trackingRepository.octopusUISessionEnded()
            gamificationRulesViewManager.setHomeScreenVisible(false)
        }
        .gamificationRulesSheet(
            isPresented: $gamificationRulesViewManager.shouldDisplayGamificationRules,
            gamificationConfig: gamificationRulesViewManager.gamificationConfig,
            gamificationRulesViewManager: gamificationRulesViewManager)
        // set the environment, this will set the default environment if no other has been set, and avoid re-creating
        // the default env each time it is accessed
        .environment(\.octopusTheme, theme)
        .environmentObject(translationStore)
        .environment(\.trackingApi, trackingApi)
        .environmentObject(gamificationRulesViewManager)
        .environmentObject(displayConfigManager)
        .environmentObject(reactionsListManager)
        .environmentObject(videoManager)
        .environment(\.urlOpener, urlOpener)
        .environmentObject(languageManager)
        .overrideLanguageIfNeeded(languageManager: languageManager)
    }

    @available(iOS 14.0, *)
    @ViewBuilder
    private var content: some View {
        if viewModel.clientUserId != nil {
            switch viewModel.resolution {
            case .resolving:
                Compat.ProgressView()
                    .frame(width: 60)
                    .toolbar(leading: leadingBarItem, trailing: EmptyView())
            case let .resolved(profileId):
                ProfileSummaryView(octopus: octopus, mainFlowPath: viewModel.mainFlowPath,
                                   translationStore: translationStore, profileId: profileId,
                                   canClose: presentationMode.wrappedValue.isPresented,
                                   navBarLeadingAction: navBarLeadingAction)
            case .notFound:
                ProfileUnavailableView(canClose: presentationMode.wrappedValue.isPresented,
                                       navBarLeadingAction: navBarLeadingAction)
            }
        } else if viewModel.isConnected {
            CurrentUserProfileSummaryView(octopus: octopus, mainFlowPath: viewModel.mainFlowPath,
                                          translationStore: translationStore,
                                          gamificationRulesViewManager: gamificationRulesViewManager,
                                          canClose: presentationMode.wrappedValue.isPresented,
                                          navBarLeadingAction: navBarLeadingAction)
        } else {
            ProfileUnavailableView(canClose: presentationMode.wrappedValue.isPresented,
                                   navBarLeadingAction: navBarLeadingAction)
        }
    }

    // `ProfileSummaryView` / `CurrentUserProfileSummaryView` wire their own leading bar item internally
    // (they already own a full toolbar via `zoomableImageContainer`, see `4719e869`); this covers the one
    // remaining `content` branch that renders bare (no toolbar owner of its own): the clientUserId
    // resolution spinner. `ProfileUnavailableView` below owns its own copy of this same pattern, since it
    // is a full, independent view (not a modifier applied to a caller's content).
    @available(iOS 14.0, *)
    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction)
        } else if presentationMode.wrappedValue.isPresented {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else {
            EmptyView()
        }
    }
}

/// Generic fallback shown when the requested profile cannot be displayed: an unresolved `clientUserId`
/// (unknown id, the community does not expose client user ids, or a network failure), or no connected
/// session at all in self mode. Reuses the same "Error.Unknown" generic message as
/// `ServerCallError.displayableMessage` and `CommunityAccessDeniedView` — no new wording is introduced.
private struct ProfileUnavailableView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    private let canClose: Bool
    private let navBarLeadingAction: OctopusNavBarLeadingAction?

    init(canClose: Bool = false, navBarLeadingAction: OctopusNavBarLeadingAction? = nil) {
        self.canClose = canClose
        self.navBarLeadingAction = navBarLeadingAction
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Error.Unknown", bundle: .module)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.gray900)
                .multilineTextAlignment(.center)

            Spacer()

            PoweredByOctopusView()
        }
        .padding(.horizontal, 24)
        .toolbar(leading: leadingBarItem, trailing: EmptyView())
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if let navBarLeadingAction {
            NavBarLeadingActionButton(navBarLeadingAction)
        } else if canClose {
            CloseButton(action: { presentationMode.wrappedValue.dismiss() })
        } else {
            EmptyView()
        }
    }
}
