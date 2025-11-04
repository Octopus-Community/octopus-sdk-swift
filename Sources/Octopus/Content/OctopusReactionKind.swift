//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A reaction on a content
public enum OctopusReactionKind: Equatable, Sendable {
    /// ❤️ reaction
    case heart
    /// 😂 reaction
    case joy
    /// 😮 reaction
    case mouthOpen
    /// 👏 reaction
    case clap
    /// 😢 reaction
    case cry
    /// 😡 reaction
    case rage
    /// Unknown reaction, probably coming from a more up-to-date SDK
    case unknown(String)

    public var unicode: String {
        switch self {
        case .heart: return "❤️"
        case .joy: return "😂"
        case .mouthOpen: return "😮"
        case .clap: return "👏"
        case .cry: return "😢"
        case .rage: return "😡"
        case .unknown(let string): return string
        }
    }
}
