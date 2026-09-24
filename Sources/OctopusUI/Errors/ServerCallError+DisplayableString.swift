//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

extension ServerCallError {
    var displayableMessage: DisplayableString {
        switch self {
        case .noNetwork:
            return .localizationKey("Error.NoNetwork")
        case let .serverError(serverError):
            // The server explains why it refused; show that rather than a generic message. An absent or
            // empty reason falls back to a dedicated string, never to an empty one.
            switch serverError {
            case let .notAuthenticated(reason):
                if let reason { return .localizedString(reason) }
            case let .permissionDenied(reason):
                return reason.map { DisplayableString.localizedString($0) }
                    ?? .localizationKey("Error.PermissionDenied")
            default:
                break
            }
            fallthrough
        default:
            return .localizationKey("Error.Unknown")
        }
    }
}
