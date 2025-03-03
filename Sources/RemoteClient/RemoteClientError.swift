//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GRPC

/// The errors that can be reported from any remote client call
public enum RemoteClientError: Error {
    case cancelled
    case timeout
    case notAuthenticated(reason: String?)
    case notFound
    case unknown(Error)

    init(error: Error) {
        guard let gprcStatus = error as? GRPCStatus else {
            self = .unknown(error)
            return
        }
        switch gprcStatus.code {
        case .cancelled:            self = .cancelled
        case .deadlineExceeded:     self = .timeout
        case .unauthenticated:      self = .notAuthenticated(reason: gprcStatus.message)
        case .notFound:             self = .notFound
        default:                    self = .unknown(error)
        }
    }
}
