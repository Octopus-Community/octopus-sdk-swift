//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Any kind of toast that the UI should display
public enum Toast: Equatable, Sendable {
    case gamification(GamificationToast)
    case userAction(UserActionToast)
    case error(ErrorToast)
}

/// Toasts related to the gamification
public struct GamificationToast: Equatable, Sendable {
    public let action: GamificationAction
    public let formattedPoints: String
}

/// Toasts related to user actions
public enum UserActionToast: Equatable, Sendable {
    case postCreated
}

/// Toasts representing error states
public enum ErrorToast: Equatable, Sendable {
    /// The device lost its connection. Stays on screen until the connection is back (Screen states spec).
    case noNetwork
    /// Any other failure raised while content was already displayed. Transient, and retriable when the
    /// screen offers a retry.
    case unknown
}
