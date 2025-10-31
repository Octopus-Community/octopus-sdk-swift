//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A reaction on a content
public enum ReactionKind: Equatable, Hashable, Sendable {
    case heart
    case joy
    case mouthOpen
    case clap
    case cry
    case rage
    case unknown(String)

    init(unicode: String) {
        switch unicode {
        case "❤️": self = .heart
        case "😂": self = .joy
        case "😮": self = .mouthOpen
        case "👏": self = .clap
        case "😢": self = .cry
        case "😡": self = .rage
        default: self = .unknown(unicode)
        }
    }

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

    public static let knownValues: [ReactionKind] = [
        .heart,
        .joy,
        .mouthOpen,
        .clap,
        .cry,
        .rage,
    ]
}
