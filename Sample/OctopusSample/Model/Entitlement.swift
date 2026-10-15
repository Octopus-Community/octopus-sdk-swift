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
    case verified = "customer:verified"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .premium: return "Premium"
        case .moderator: return "Moderator"
        case .verified: return "Verified"
        }
    }

    /// What the entitlement grants on the demo community, in one line.
    var summary: String {
        switch self {
        case .premium: return "Unlocks the gated \"Premium\" topic"
        case .moderator: return "Grants moderation actions on posts"
        case .verified: return "Marks the profile as verified"
        }
    }
}

extension Entitlement {
    /// The stored form: the backend strings, sorted so the same set always writes the same value.
    static func encode(_ entitlements: Set<Entitlement>) -> [String] {
        entitlements.map(\.rawValue).sorted()
    }

    /// Back from the stored form; a string this build no longer knows is dropped.
    static func decode(_ stored: [String]?) -> Set<Entitlement> {
        Set((stored ?? []).compactMap(Entitlement.init(rawValue:)))
    }
}
