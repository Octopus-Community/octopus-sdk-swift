//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration related to how to display things
public struct DisplayConfig: Equatable, Sendable {
    public let poweredByOctopus: PoweredByOctopus

    public enum PoweredByOctopus: Equatable, Sendable {
        case normal
        case custom(DarkLightValue<URL>)
        case hidden
    }
}

extension DisplayConfig {
    init(from entity: DisplayConfigEntity) {
        poweredByOctopus = if entity.poweredByIsHidden {
            .hidden
        } else if let lightUrl = entity.poweredByLightUrl, let darkUrl = entity.poweredByDarkUrl {
            .custom(.init(lightValue: lightUrl, darkValue: darkUrl))
        } else {
            .normal
        }
    }

    init(from config: Com_Octopuscommunity_DisplayConfig) {
        poweredByOctopus = .init(from: config.poweredByOctopus)
    }
}

extension DisplayConfig.PoweredByOctopus {
    init(from config: Com_Octopuscommunity_PoweredByOctopus) {
        switch config.logo {
        case .default: self = .normal
        case let .custom(urls):
            if let lightUrl = URL(string: urls.lightLogoURL), let darkUrl = URL(string: urls.darkLogoURL) {
                self = .custom(.init(lightValue: lightUrl, darkValue: darkUrl))
            } else {
                self = .normal
            }
        case .hidden: self = .hidden
        case .none: self = .normal
        }
    }
}
