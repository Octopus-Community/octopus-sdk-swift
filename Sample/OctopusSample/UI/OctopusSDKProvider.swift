//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// This class is a singleton that provides a publisher of the notification device token
/// It is here because, due to the multiple way of initializing the SDK, it is not created in the AppDelegate as you
/// should do it. If you create the SDK in your AppDelegate, you can directly call the function `` when receiving the
/// device token.
class OctopusSDKProvider {

    static let instance = OctopusSDKProvider()

    /// Whether the app is in demo mode (internal tests only).
    @Published private(set) var octopus: OctopusSDK?

    private var lastApiKeyUsed: String?

    private var storage = [AnyCancellable]()
    
    /// Creates a new SDK instance, if needed.
    /// - Parameters:
    ///   - connectionMode: the connection mode
    ///   - forceNew: if true, the SDK will be created, even if the current instance is the same as the one requested
    func createSDK(connectionMode: ConnectionMode, forceNew: Bool = false) {
        let apiKey = switch connectionMode {
        case .octopus: APIKeys.octopusAuth
        case let .sso(config):
            if config.appManagedFields.isEmpty {
                APIKeys.ssoNoManagedFields
            } else if config.appManagedFields == Set(ConnectionMode.SSOConfiguration.ProfileField.allCases) {
                APIKeys.ssoAllManagedFields
            } else {
                APIKeys.ssoSomeManagedFields
            }
        }
        guard (apiKey != lastApiKeyUsed || forceNew) else { return }
        lastApiKeyUsed = apiKey
        printSdkCreation(connectionMode: connectionMode)
        octopus = try! OctopusSDK(apiKey: apiKey, connectionMode: connectionMode)
    }

    private func printSdkCreation(connectionMode: ConnectionMode) {
        switch connectionMode {
        case .octopus: print("Create SDK with connection mode: Octopus")
        case let .sso(config):
            if config.appManagedFields.isEmpty {
                print("Create SDK with connection mode: SSO with no app managed fields")
            } else if config.appManagedFields == Set(ConnectionMode.SSOConfiguration.ProfileField.allCases) {
                print("Create SDK with connection mode: SSO with all managed fields")
            } else {
                print("Create SDK with connection mode: SSO with some managed fields")
            }
        }
    }
}
