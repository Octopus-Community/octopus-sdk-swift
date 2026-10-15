//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// The config of the SDK. For internal use only.
struct SDKConfig: Codable, Equatable {
    enum ProfileField: CaseIterable, Codable, Equatable {
        /// Username
        case nickname
        /// Biography
        case bio
        /// Profile picture
        case picture
    }

    /// A config persisted with a kind that no longer exists fails to decode, so the Sample asks for a
    /// new one at launch instead of crashing.
    enum AuthKind: Codable, Equatable {
        case sso(appManagedFields: [ProfileField], forceLoginOnStrongActions: Bool = false)

        var displayableString: String {
            switch self {
            case let .sso(appManagedFields, forceLoginOnStrongActions):
                let fieldsStr = switch appManagedFields.count {
                case 0: "SSO without any app managed fields"
                case ProfileField.allCases.count: "SSO with all app managed fields"
                default: "SSO with \(appManagedFields.map { "\($0)" }.joined(separator: " and ")) as app managed fields"
                }
                return "\(fieldsStr), force login on strong actions: \(forceLoginOnStrongActions)"
            }
        }
    }

    /// A host typed on Configuration › Server environment › Custom host, for internal testing.
    struct CustomServer: Codable, Equatable {
        let host: String
        let port: Int

        /// The production backend, the Config screen's "Prod (api.8pus.io)" option, as Android's `ServerOverride`.
        static let prod = CustomServer(host: "api.8pus.io", port: 443)

        var isProd: Bool { self == .prod }
    }

    var authKind: AuthKind

    /// Feature env the Sample targets, when the developer picked one. `nil` → default community.
    /// Optional so configs persisted before this feature still decode.
    var featureEnv: FeatureEnvSelection?

    /// The custom host the SDK talks to, `nil` for the demo server. Ignored while a feature env is set: the env
    /// carries its own endpoint. Optional so configs persisted before this field still decode.
    var customServer: CustomServer?

    /// An API key pasted on Configuration › Community › Custom, `nil` for the demo presets. Ignored while a
    /// feature env is set, whose key wins. Optional so configs persisted before this field still decode.
    var customApiKey: String?

    func with(featureEnv: FeatureEnvSelection?) -> SDKConfig {
        var copy = self
        copy.featureEnv = featureEnv
        return copy
    }

    /// Another auth shape, keeping everything else: server, community and feature env.
    func with(authKind: AuthKind) -> SDKConfig {
        var copy = self
        copy.authKind = authKind
        return copy
    }

    var displayableString: String {
        authKind.displayableString
    }
}

private extension UserDefaults {
    func setEnum<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        }
    }

    func getEnum<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

class SDKConfigManager {
    static let instance = SDKConfigManager()

    @Published private(set) var sdkConfig: SDKConfig?
    private let sdkConfigKey = "sdkConfig"

    private init() {
        sdkConfig = UserDefaults.standard.getEnum(SDKConfig.self, forKey: sdkConfigKey)
    }

    func set(config: SDKConfig) {
        UserDefaults.standard.setEnum(config, forKey: sdkConfigKey)
        sdkConfig = config
    }

    /// Forgets the saved config, for Settings › Reset configuration. In internal demo mode the app then shows the
    /// Config screen again (see `SampleRootView`).
    func clear() {
        UserDefaults.standard.removeObject(forKey: sdkConfigKey)
        sdkConfig = nil
    }

    /// Stores (or clears) the selected feature env, keeping the rest of the config untouched.
    func setFeatureEnv(_ selection: FeatureEnvSelection?) {
        guard let sdkConfig else { return }
        set(config: sdkConfig.with(featureEnv: selection))
    }
}
