//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct ReactionKind: Equatable, Hashable, Sendable {
    public let unicode: String

    public static let heart =       ReactionKind(unicode: "❤️")
    public static let joy =         ReactionKind(unicode: "😂")
    public static let mouthOpen =   ReactionKind(unicode: "😮")
    public static let clap =        ReactionKind(unicode: "👏")
    public static let cry =         ReactionKind(unicode: "😢")
    public static let rage =        ReactionKind(unicode: "😡")

    public static let knownValues: [ReactionKind] = [
        Self.heart,
        Self.joy,
        Self.mouthOpen,
        Self.clap,
        Self.cry,
        Self.rage,
    ]
}
