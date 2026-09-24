//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif

/// The errors that can be reported from any remote client call
public enum RemoteClientError: Error {
    case cancelled
    case timeout
    case notAuthenticated(reason: String?)
    /// The server refused the action on a rights basis. `reason` is the server's own explanation, meant
    /// to be shown to the member as-is.
    case permissionDenied(reason: String?)
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
        case .permissionDenied:
            // An empty message counts as absent, so the UI never shows a blank alert.
            self = .permissionDenied(reason: gprcStatus.message?.isEmpty == false ? gprcStatus.message : nil)
        case .notFound:             self = .notFound
        default:                    self = .unknown(error)
        }
    }
}
