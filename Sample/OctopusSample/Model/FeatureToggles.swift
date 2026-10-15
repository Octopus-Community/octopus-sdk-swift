//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// A boolean SDK option a tester flips from the header of the Scenarios section it belongs to, and from nowhere
/// else. Every toggle owns its effect sentence, in product words, for both positions.
enum FeatureToggle: String, CaseIterable, Identifiable {
    case forceLogin = "force-login"
    case pushRegistration = "push-registration"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .forceLogin: "Force login"
        case .pushRegistration: "Push registration"
        }
    }

    var testId: String { "scenarios-toggle-\(rawValue)" }

    /// The line rendered under the switch on the Scenarios section header.
    func effectLine(enabled: Bool) -> String {
        switch (self, enabled) {
        case (.forceLogin, true): "Visitors must sign in before they can read or post."
        case (.forceLogin, false): "Visitors can browse the community before signing in."
        case (.pushRegistration, true): "New device tokens go to Octopus, so this device can be notified."
        case (.pushRegistration, false): "Device tokens stay in the app; already-registered ones live until a reset."
        }
    }

    /// Read-only state, as the scenario screen shows it: "Force login is on".
    func stateLine(enabled: Bool) -> String { "\(label) is \(enabled ? "on" : "off")" }

    /// The value Configuration reads without offering a second switch: "on · set in Scenarios".
    func readOnlyValueLine(enabled: Bool) -> String { "\(enabled ? "on" : "off") · set in Scenarios" }
}

/// The live position of every `FeatureToggle`.
///
/// Push registration is the Sample's own switch, persisted here, and gates the sink that hands device tokens to
/// the SDK (see `OctopusSDKProvider`). Force login is a field of the persisted `SDKConfig`: it is read from there
/// and written back there, never copied.
final class FeatureToggles: ObservableObject {
    static let instance = FeatureToggles()

    static let pushRegistrationKey = "OctopusSample.featureToggles.pushRegistration"

    /// Whether new device tokens are handed to Octopus. On by default.
    @Published private(set) var pushRegistrationEnabled: Bool
    /// Whether the persisted config asks for login on strong actions.
    @Published private(set) var forceLoginEnabled: Bool = false
    /// Whether flipping force login changes anything: the key only depends on it for an SSO config without app
    /// managed fields, outside a feature env and a custom API key, and only internal demo mode builds the SDK from
    /// that config.
    @Published private(set) var forceLoginAvailable: Bool = false

    private let defaults: UserDefaults
    private var storage = [AnyCancellable]()

    init(defaults: UserDefaults = .standard,
         sdkConfig: AnyPublisher<SDKConfig?, Never>? = nil,
         internalDemoMode: Bool = DefaultValuesProvider.internalDemoMode) {
        self.defaults = defaults
        pushRegistrationEnabled = defaults.object(forKey: Self.pushRegistrationKey) as? Bool ?? true
        (sdkConfig ?? SDKConfigManager.instance.$sdkConfig.eraseToAnyPublisher())
            .sink { [weak self] config in
                guard let self else { return }
                forceLoginEnabled = Self.forceLogin(of: config)
                forceLoginAvailable = Self.isForceLoginAvailable(config: config, internalDemoMode: internalDemoMode)
            }
            .store(in: &storage)
    }

    func isEnabled(_ toggle: FeatureToggle) -> Bool {
        switch toggle {
        case .forceLogin: forceLoginEnabled
        case .pushRegistration: pushRegistrationEnabled
        }
    }

    func isAvailable(_ toggle: FeatureToggle) -> Bool {
        switch toggle {
        case .forceLogin: forceLoginAvailable
        case .pushRegistration: true
        }
    }

    /// Every toggle and its position, in one line: "Force login off · Push registration on".
    var summaryLine: String { Self.summaryLine(isEnabled(_:)) }

    static func summaryLine(_ isEnabled: (FeatureToggle) -> Bool) -> String {
        FeatureToggle.allCases.map { "\($0.label) \(isEnabled($0) ? "on" : "off")" }.joined(separator: " · ")
    }

    func setPushRegistrationEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.pushRegistrationKey)
        pushRegistrationEnabled = enabled
        SampleDebugLog.instance.logToggle(.pushRegistration, enabled: enabled)
    }

    /// Rewrites the persisted config and rebuilds the SDK on it, as a host shipping the other setting would.
    @MainActor
    func setForceLogin(_ enabled: Bool) async throws {
        guard let config = SDKConfigManager.instance.sdkConfig,
              case let .sso(appManagedFields, _) = config.authKind else { return }
        // A copy, not a new config: the server, the custom community and the feature env stay as they are.
        let updated = config.with(authKind: .sso(appManagedFields: appManagedFields,
                                                 forceLoginOnStrongActions: enabled))
        SDKConfigManager.instance.set(config: updated)
        try await OctopusSDKProvider.instance.switchCommunityFromConfig()
        NotificationCenter.default.post(name: .apiKeyChanged, object: nil)
        SampleDebugLog.instance.logToggle(.forceLogin, enabled: enabled)
    }

    static func forceLogin(of config: SDKConfig?) -> Bool {
        guard case let .sso(_, forceLogin)? = config?.authKind else { return false }
        return forceLogin
    }

    static func isForceLoginAvailable(config: SDKConfig?, internalDemoMode: Bool) -> Bool {
        guard internalDemoMode, let config, config.featureEnv == nil, config.customApiKey == nil,
              case let .sso(appManagedFields, _) = config.authKind else { return false }
        return appManagedFields.isEmpty
    }
}
