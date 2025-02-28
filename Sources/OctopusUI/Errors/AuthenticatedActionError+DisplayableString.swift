//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

extension AuthenticatedActionError {
    var displayableMessage: DisplayableString {
        switch self {
        case .noNetwork:
            return .localizationKey("Error.NoNetwork")
        case let .serverError(serverError):
            if case let .notAuthenticated(reason) = serverError, let reason {
                return .localizedString(reason)
            }
            fallthrough
        default:
            return .localizationKey("Error.Unknown")
        }
    }
}
