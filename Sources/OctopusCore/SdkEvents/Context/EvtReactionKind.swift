//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
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
    }
}

extension ReactionKind {
    var sdkEventValue: SdkEvent.ReactionKind {
        switch self {
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
