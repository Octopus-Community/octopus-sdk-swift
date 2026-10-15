//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusUI

/// The Community tab, in the `CommunityNavigation` mode chosen in Settings › Host app integration.
///
/// - In tab: the Octopus UI embedded directly in the tab. It is deliberately not wrapped in a
///   `NavigationView` / `NavigationStack`: `OctopusHomeScreen` owns its navigation, and its pushes and pops
///   stay inside this tab, above the tab bar. The `TabView` keeps this view alive across tab switches, so
///   the SDK navigation stack is still there when the tester comes back.
/// - Full screen: the tab shows a launcher, and the shell presents the SDK screens above the tabs.
struct CommunityTabView: View {
    @StateObjectCompat private var viewModel = SampleSDKViewModel()
    @ObservedObject private var navigation = CommunityNavigationManager.instance
    @ObservedObject var router: SampleTabRouter

    var body: some View {
        switch navigation.mode {
        case .inTab:
            // You can pass a `bottomSafeAreaInset` in order to add some safe area at the bottom of
            // `OctopusHomeScreen`.
            OctopusUIView(
                octopus: viewModel.octopus,
                bottomSafeAreaInset: 10,
                octopusNotificationUserInfo: $router.pendingNotificationUserInfo)
                // The Settings › Appearance preset: the sample's navy theme by default, or no theme at all
                // ("SDK default"). It re-themes the open community at once. The Custom Theme scenario demos
                // a full custom theme.
                .sampleCommunityTheme()
                // A new id brings the SDK back to its feed: second tap on the tab, mode or community change.
                .id(router.communityStackID)
        case .fullScreen:
            SampleNavigationContainer {
                CommunityFullScreenLauncher(open: router.presentCommunityFullScreen)
            }
        }
    }
}

/// The SDK screens presented above the tabs, in the Full screen `CommunityNavigation` mode.
///
/// `.navigationStack` is the SDK's mode for a modal presentation; the SDK draws its own close button on the
/// root screen because it is presented natively, and swipe-back works on every pushed screen.
struct CommunityFullScreenView: View {
    @StateObjectCompat private var viewModel = SampleSDKViewModel()
    @Binding var octopusNotificationUserInfo: [AnyHashable: Any]?

    var body: some View {
        OctopusUIView(
            octopus: viewModel.octopus,
            navigationMode: .navigationStack,
            octopusNotificationUserInfo: $octopusNotificationUserInfo)
            // The Settings › Appearance preset, as in the tab.
            .sampleCommunityTheme()
    }
}

/// What the Community tab shows in Full screen mode, behind the presented SDK screens: one line on the mode
/// and a way to open the community again once it has been closed.
private struct CommunityFullScreenLauncher: View {
    let open: () -> Void

    var body: some View {
        VStack(spacing: SampleTokens.Spacing.space4) {
            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                .font(.title2)
                .foregroundColor(SampleTokens.Colors.accentText)
                .frame(width: SampleTokens.Size.stateDisc, height: SampleTokens.Size.stateDisc)
                .background(Circle().fill(SampleTokens.Colors.accentTint))
                .accessibilityHidden(true)
            VStack(spacing: SampleTokens.Spacing.space2) {
                Text("Community opens full screen")
                    .font(SampleTokens.Typography.headline)
                    .foregroundColor(SampleTokens.Colors.text)
                Text("The community screens are presented above the tabs. " +
                     "Change it in Settings, Host app integration.")
                    .font(SampleTokens.Typography.callout)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: open) {
                Text("Open community")
                    .font(SampleTokens.Typography.buttonLabel)
                    .foregroundColor(SampleTokens.Colors.buttonText)
                    .frame(maxWidth: .infinity, minHeight: SampleTokens.Size.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: SampleTokens.Radius.large, style: .continuous)
                            .fill(SampleTokens.Colors.buttonBackground)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityId("community-open-fullscreen")
        }
        .padding(.horizontal, SampleTokens.Spacing.space8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sampleScreenBackground()
        .accessibilityId("community-fullscreen-launcher")
        .sampleTabRoot("Community")
    }
}

/// The unread-notification count shown on the Community tab badge, the same SDK value Android reads.
@MainActor
final class CommunityTabBadgeViewModel: ObservableObject {
    @Published private(set) var unreadCount = 0

    private let countPublisher: () -> AnyPublisher<Int, Never>?
    private var countSubscription: AnyCancellable?
    private var storage = [AnyCancellable]()

    /// Badge text: the count, capped at "+99" like Android, or `nil` to hide the badge.
    var badgeText: String? { Self.badgeText(for: unreadCount) }

    /// - Parameters:
    ///   - countPublisher: the unread count of the *current* SDK instance, read again on every community
    ///     switch. Injected by the tests; the app reads `OctopusSDKProvider`.
    ///   - communitySwitches: fires when the SDK is rebuilt for another community (API key change).
    init(
        countPublisher: @escaping () -> AnyPublisher<Int, Never>? = {
            OctopusSDKProvider.instance.octopus?.$notSeenNotificationsCount.eraseToAnyPublisher()
        },
        communitySwitches: AnyPublisher<Void, Never> = NotificationCenter.default
            .publisher(for: .apiKeyChanged).map { _ in () }.eraseToAnyPublisher()
    ) {
        self.countPublisher = countPublisher
        subscribe()
        // A community switch rebuilds the SDK: follow the new instance's count.
        communitySwitches
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.subscribe() }
            .store(in: &storage)
    }

    /// The badge for an unread count: hidden at 0, the count up to 99, "+99" above.
    nonisolated static func badgeText(for count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "+99" : "\(count)"
    }

    func refresh() {
        let octopus = OctopusSDKProvider.instance.octopus
        Task { try? await octopus?.updateNotSeenNotificationsCount() }
    }

    private func subscribe() {
        unreadCount = 0
        countSubscription = countPublisher()?
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.unreadCount = $0 }
    }
}
