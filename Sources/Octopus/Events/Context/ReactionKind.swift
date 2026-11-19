//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// A reaction on a content
    #if hasAttribute(nonexhaustive)
    @nonexhaustive(warn)
    #endif
    public enum ReactionKind: Sendable {
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
}

extension OctopusEvent.ReactionKind {
    init?(from kind: SdkEvent.ReactionKind?) {
        guard let kind else { return nil }
        self = switch kind {
        case .heart: .heart
        case .joy: .joy
        case .mouthOpen: .mouthOpen
        case .clap: .clap
        case .cry: .cry
        case .rage: .rage
        case let .unknown(string): .unknown(string)
        }
    }
}
