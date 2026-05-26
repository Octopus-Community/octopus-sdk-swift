//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Local representation of the entitlement strings the backend recognizes for the
/// sample app's API key.
/// Talk with our team to configure your own entitlements.
enum Entitlement: String, CaseIterable, Hashable, Identifiable {
    case premium = "customer:premium"
    case moderator = "customer:moderator"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .premium: return "Premium"
        case .moderator: return "Moderator"
        }
    }
}
