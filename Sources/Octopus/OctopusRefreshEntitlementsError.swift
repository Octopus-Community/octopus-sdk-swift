//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Errors that may be thrown by ``OctopusSDK/refreshEntitlements()``.
public enum OctopusRefreshEntitlementsError: Error, Sendable, CustomDebugStringConvertible {
    /// No `tokenProvider` has been registered yet: call `connectUser(_:tokenProvider:)` first, the
    /// refresh exchanges a fresh token obtained from it.
    case noClientTokenProvider
    /// No connected user (guest, or user not connected).
    case userNotConnected
    /// No network connection available.
    case noNetwork
    /// The user has been banned from the community. The associated string is the
    /// backend-provided message and is appropriate for display.
    case userBanned(String)
    /// The backend returned an error.
    case serverError(Error)

    public var debugDescription: String {
        switch self {
        case .noClientTokenProvider:
            return "refreshEntitlements requires a tokenProvider registered through connectUser."
        case .userNotConnected:
            return "refreshEntitlements requires a connected (non-guest) user."
        case .noNetwork:
            return "refreshEntitlements failed: no network."
        case .userBanned(let message):
            return "refreshEntitlements user banned: \(message)"
        case .serverError(let error):
            return "refreshEntitlements server error: \(error)"
        }
    }
}
