//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// The config of the SDK. For internal use only.
struct SDKConfig: Codable {
    enum ProfileField: CaseIterable, Codable, Equatable {
        /// Username
        case nickname
        /// Biography
        case bio
        /// Profile picture
        case picture
    }

    enum AuthKind: Codable {
        case octopus
        case sso(appManagedFields: [ProfileField], forceLoginOnStrongActions: Bool = false)

        var displayableString: String {
            switch self {
            case .octopus:
                return "Octopus authentication"
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

    let authKind: AuthKind

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
}
