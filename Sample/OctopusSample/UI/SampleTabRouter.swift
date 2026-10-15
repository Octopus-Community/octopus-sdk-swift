//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import UIKit

/// The three tabs of the sample shell, in the order and with the test ids of the Android sample.
enum SampleTab: Hashable, CaseIterable {
    case scenarios
    case community
    case settings

    var title: String {
        switch self {
        case .scenarios: return "Scenarios"
        case .community: return "Community"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .scenarios: return "testtube.2"
        case .community: return "bubble.left.and.bubble.right"
        case .settings: return "gearshape"
        }
    }

    /// Accessibility identifier, identical to the Android `testTag` so one QA script drives both samples.
    var accessibilityId: String {
        switch self {
        case .scenarios: return "scenarios-tab"
        case .community: return "community-tab"
        case .settings: return "settings-tab"
        }
    }
}

/// Owns the selected tab, so a screen inside one tab can send the tester to another (a scenario's
/// "Embedded in a tab" row), the routing of a tapped push notification, and the Community tab's
/// navigation, in either `CommunityNavigation` mode.
///
/// The selection is not persisted: like Android, the app always starts on Scenarios.
@MainActor
final class SampleTabRouter: ObservableObject {
    static let instance = SampleTabRouter()

    @Published private(set) var selectedTab: SampleTab = .scenarios

    /// The last place the tester was outside Settings, "Scenarios › connection" or "Community": Send feedback
    /// is opened from Settings, so it reports where the tester came from, as Android does.
    var lastContentBreadcrumb = "Scenarios"

    /// The payload of a tapped Octopus push, waiting for the `OctopusHomeScreen` of the current mode: the
    /// one in the Community tab (In tab) or the one presented above the tabs (Full screen).
    ///
    /// Bound as the SDK's `notificationUserInfo`, which resets it to `nil` once it has opened the target
    /// screen. Only one `OctopusHomeScreen` is bound to it at a time, so the payload is delivered once.
    @Published var pendingNotificationUserInfo: [AnyHashable: Any]?

    /// The identity of the Community tab's SDK navigation. A new value rebuilds `OctopusHomeScreen` on its
    /// feed: the host has no handle on the SDK's own navigation path, so this is how it pops it.
    @Published private(set) var communityStackID = UUID()

    /// Whether the SDK screens are presented above the tabs (Full screen mode only).
    @Published var isCommunityFullScreenPresented = false

    /// Fires when every open presentation (sheet, full screen cover) must close, so a routed push is
    /// shown in the community and not hidden behind a scenario's modal.
    let dismissPresentations = PassthroughSubject<Void, Never>()

    var communityNavigation: CommunityNavigation { navigation.mode }

    private let navigation: CommunityNavigationManager
    private let hasOpenPresentation: @MainActor () -> Bool
    private let waitForDismissal: @MainActor (@escaping @MainActor @Sendable (_ dismissed: Bool) -> Void) -> Void
    private var storage = [AnyCancellable]()
    /// Bumped by every reset and every routed push, so a Full screen presentation deferred behind a modal
    /// is dropped when the community was reset (mode change, community switch) or another push superseded
    /// it before the modal had gone.
    private var routingGeneration = 0

    /// Internal so tests can build an isolated router; the app uses `instance`.
    /// - Parameters:
    ///   - navigation: the persisted `CommunityNavigation` choice.
    ///   - communitySwitches: fires when the SDK is rebuilt for another community (API key change).
    ///   - hasOpenPresentation: whether a modal is on screen when a push is routed in Full screen mode.
    ///   - waitForDismissal: calls back once that modal has gone (`true`), or when it is still on screen after
    ///     the wait (`false`). UIKit refuses to present while another presentation is still animating out.
    init(
        navigation: CommunityNavigationManager = .instance,
        communitySwitches: AnyPublisher<Void, Never> = NotificationCenter.default
            .publisher(for: .apiKeyChanged).map { _ in () }.eraseToAnyPublisher(),
        hasOpenPresentation: @escaping @MainActor () -> Bool = { SampleTabRouter.rootHasPresentation() },
        waitForDismissal: @escaping @MainActor (@escaping @MainActor @Sendable (_ dismissed: Bool) -> Void) -> Void = { done in
            Task { @MainActor in
                // Waits for the modal to be actually gone (dismissal animations vary), bounded at ~2 s.
                for _ in 0..<40 where SampleTabRouter.rootHasPresentation() {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                done(!SampleTabRouter.rootHasPresentation())
            }
        }
    ) {
        self.navigation = navigation
        self.hasOpenPresentation = hasOpenPresentation
        self.waitForDismissal = waitForDismissal

        // A mode change or a community switch starts the community over, on the feed. The mode is only
        // changed from Settings, on the main thread; a switch can be posted from the SDK provider's tasks.
        // Duplicates are removed before the current value is dropped: setting the same mode again is no change.
        navigation.$mode
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.resetCommunity() }
            .store(in: &storage)
        communitySwitches
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.resetCommunity() }
            .store(in: &storage)
    }

    /// Selects a tab, from the tab bar or from a screen.
    ///
    /// - Community selected again while In tab: the SDK navigation goes back to the feed, as a second tap
    ///   on the current tab does in the system apps.
    /// - Community in Full screen: the tab shows a launcher and the SDK screens are presented above it.
    func select(_ tab: SampleTab) {
        if tab == .community {
            lastContentBreadcrumb = "Community"
            switch navigation.mode {
            case .inTab:
                if selectedTab == .community { communityStackID = UUID() }
            case .fullScreen:
                isCommunityFullScreenPresented = true
            }
        }
        selectedTab = tab
    }

    /// Presents the SDK screens above the tabs (Full screen mode).
    func presentCommunityFullScreen() {
        isCommunityFullScreenPresented = true
    }

    /// Routes a tapped push notification. The shell is its only consumer: it closes whatever scenario
    /// presentation is open, then hands the payload to the community of the current mode, once.
    ///
    /// - In tab: selects Community, whose `OctopusHomeScreen` opens the target screen.
    /// - Full screen: keeps the current tab and presents the SDK screens above it, or lets the already
    ///   presented ones open the target screen.
    func routeNotification(userInfo: [AnyHashable: Any]) {
        routingGeneration += 1
        switch navigation.mode {
        case .inTab:
            dismissPresentations.send()
            selectedTab = .community
            pendingNotificationUserInfo = userInfo
        case .fullScreen:
            guard !isCommunityFullScreenPresented else {
                // The SDK screens stay up; only the host modals drawn above them close.
                dismissPresentations.send()
                pendingNotificationUserInfo = userInfo
                return
            }
            let mustWait = hasOpenPresentation()
            dismissPresentations.send()
            pendingNotificationUserInfo = userInfo
            if mustWait {
                let generation = routingGeneration
                waitForDismissal { [weak self] dismissed in
                    // A modal that refused to close keeps the cover from presenting: the payload stays
                    // pending and opens with the community the next time it is presented.
                    guard let self, dismissed, self.routingGeneration == generation else { return }
                    self.isCommunityFullScreenPresented = true
                }
            } else {
                isCommunityFullScreenPresented = true
            }
        }
    }

    /// Closes the community and starts it over on its feed: Settings › Host app integration › Restart now. Host
    /// integration changes already apply to the live SDK; this is what makes a screen that is already open
    /// pick them up, without quitting the app.
    func restartCommunity() {
        resetCommunity()
    }

    private func resetCommunity() {
        routingGeneration += 1
        pendingNotificationUserInfo = nil
        isCommunityFullScreenPresented = false
        communityStackID = UUID()
    }

    /// Whether the app's root view controller is presenting something (a sheet or a full screen cover).
    static func rootHasPresentation() -> Bool {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .contains { $0.presentedViewController != nil }
    }
}

extension View {
    /// Closes this presentation when the shell routes a push to the community.
    func dismissedOnPushRouting(_ isPresented: Binding<Bool>) -> some View {
        onReceive(SampleTabRouter.instance.dismissPresentations) { _ in
            isPresented.wrappedValue = false
        }
    }

    /// Closes this item-driven presentation when the shell routes a push to the community.
    func dismissedOnPushRouting<Item>(_ item: Binding<Item?>) -> some View {
        onReceive(SampleTabRouter.instance.dismissPresentations) { _ in
            item.wrappedValue = nil
        }
    }
}
