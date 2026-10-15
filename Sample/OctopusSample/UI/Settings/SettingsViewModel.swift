//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

/// The one-word answer to "is the SDK usable right now?", as the Android sample's `SampleSdkStatus`.
enum SampleSDKStatus: Equatable {
    case notStarted
    case unreachable
    case noSession
    case guest
    case signedIn

    /// iOS reads the session from `OctopusSDK.profile` (the SDK exposes no connection state of its own) and the
    /// network from the Config screen's Force offline switch (a simulator always reports a connection).
    static func of(isStarted: Bool, session: SampleSession, isForcedOffline: Bool) -> SampleSDKStatus {
        guard isStarted else { return .notStarted }
        if isForcedOffline { return .unreachable }
        guard session.hasProfile else { return .noSession }
        return session.isGuest ? .guest : .signedIn
    }

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .unreachable: return "Unreachable"
        case .noSession: return "Started, no session"
        case .guest: return "Running as guest"
        case .signedIn: return "Running, signed in"
        }
    }

    var detail: String {
        switch self {
        case .notStarted: return "Start the SDK from Configuration."
        case .unreachable: return "Forced offline: SDK calls fail until Force offline is switched off."
        case .noSession: return "The SDK has not opened a session yet, not even a guest one."
        case .guest: return "Read-only: connect an SSO user to post and react."
        case .signedIn: return "Every scenario is available."
        }
    }
}

/// The values the Settings index summarizes, and Reset configuration.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var sdkConfig: SDKConfig?
    @Published private(set) var session = SampleSession.none
    @Published private(set) var appUser: AppUser?
    @Published private(set) var languageIdentifier: String?
    @Published var isResetConfirmationPresented = false

    private let resetLocalSetup: @MainActor () -> Void
    private var storage = [AnyCancellable]()

    /// - Parameters:
    ///   - observesApp: whether to follow the app's stores and SDK. Off in the tests, which only drive the reset.
    ///   - resetLocalSetup: what Reset configuration clears. Injected by the tests; the app clears every local
    ///     store of the sample (see `Self.resetSampleSetup`).
    init(observesApp: Bool = true,
         resetLocalSetup: @escaping @MainActor () -> Void = SettingsViewModel.resetSampleSetup) {
        self.resetLocalSetup = resetLocalSetup
        guard observesApp else { return }
        SDKConfigManager.instance.$sdkConfig
            .sink { [weak self] in self?.sdkConfig = $0 }
            .store(in: &storage)
        AppUserManager.instance.$appUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.appUser = $0 }
            .store(in: &storage)
        SampleLanguageManager.instance.$overriddenLocale
            .sink { [weak self] in self?.languageIdentifier = $0?.identifier }
            .store(in: &storage)
        SampleSession.current()
            .sink { [weak self] in self?.session = $0 }
            .store(in: &storage)
    }

    var status: SampleSDKStatus {
        SampleSDKStatus.of(isStarted: OctopusSDKProvider.isCreated, session: session,
                           isForcedOffline: SampleDebugSettings.forceOffline)
    }

    var communityName: String { Self.communityName(for: sdkConfig) }
    var serverName: String { Self.serverName(for: sdkConfig) }
    var accountSubtitle: String { Self.accountSubtitle(appUser: appUser, session: session) }
    var languageSubtitle: String { SDKLanguages.summary(for: languageIdentifier) }

    func requestReset() {
        isResetConfirmationPresented = true
    }

    /// The dialog's Reset button. Local only: nothing is deleted on the server.
    func confirmReset() {
        isResetConfirmationPresented = false
        resetLocalSetup()
    }

    // MARK: - Summaries (pure, unit-tested)

    nonisolated static func communityName(for config: SDKConfig?) -> String {
        if let config { return SampleConfigSummary.community(config) }
        return DefaultValuesProvider.internalDemoMode ? "—" : "Demo community"
    }

    nonisolated static func serverName(for config: SDKConfig?) -> String {
        if let config { return SampleConfigSummary.serverEnvironment(config) }
        return DefaultValuesProvider.internalDemoMode ? "—" : "Demo"
    }

    /// Who is connected, and with how many granted entitlements, as the Android Settings Account row.
    nonisolated static func accountSubtitle(appUser: AppUser?, session: SampleSession) -> String {
        guard let appUser, session.isSignedIn else { return "Not connected · sign in with SSO" }
        let name = appUser.nickname.flatMap { $0.isEmpty ? nil : $0 } ?? appUser.userId
        return "Connected as \(name) · \(entitlementCount(session.grantedEntitlements.count))"
    }

    /// An entitlement count, spelled out.
    nonisolated static func entitlementCount(_ count: Int) -> String {
        switch count {
        case 0: return "None"
        case 1: return "1 entitlement"
        default: return "\(count) entitlements"
        }
    }

    // MARK: - Reset

    /// Clears what the tester set up in this app: the SDK config, the SSO user and its entitlements, appearance,
    /// host integration, community navigation, Unified Profile and Force offline. The language override is kept,
    /// as on Android. In internal demo mode the app then shows the Config screen; the community restarts on its
    /// feed and the app goes back to Scenarios. Nothing quits the app.
    static func resetSampleSetup() {
        AppUserManager.instance.currentEntitlements = []
        AppUserManager.instance.currentCustomEntitlements = []
        SampleDebugLog.instance.clear()
        TrackingManager.instance.clear()
        AppUserManager.instance.set(appUser: nil)
        SampleAppearanceStore.instance.reset()
        HostIntegrationStore.instance.reset()
        CommunityNavigationManager.instance.mode = .defaultValue
        UnifiedProfileManager.instance.setEnabled(false)
        SampleDebugSettings.forceOffline = false
        OctopusSDKProvider.applyDebugSettingsIfLoaded()
        SDKConfigManager.instance.clear()
        SampleTabRouter.instance.restartCommunity()
        SampleTabRouter.instance.select(.scenarios)
    }
}
