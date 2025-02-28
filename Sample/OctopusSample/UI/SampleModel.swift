//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// This is a model that provides an Octopus SDK.
/// Only needed because some scenarios are modifying the SDK.
class SampleModel: ObservableObject {
    @Published var octopus = createSdk()

    private var connectionMode: ConnectionMode = .octopus(deepLink: nil)

    func setConnectionMode(_ connectionMode: ConnectionMode) {
        octopus = Self.createSdk(connectionMode: connectionMode)
    }

    static func createSdk(
        connectionMode: ConnectionMode = .octopus(deepLink: "com.octopuscommunity.sample://magic-link"))
    -> OctopusSDK {
        let apiKey = switch connectionMode {
        case .octopus: Bundle.main.infoDictionary!["OCTOPUS_API_KEY"] as! String
        case .sso: Bundle.main.infoDictionary!["OCTOPUS_SSO_API_KEY"] as! String
        }
        return try! OctopusSDK(apiKey: apiKey, connectionMode: connectionMode)
    }
}
