//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public struct GetOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let object       = GetOptions(rawValue: 1 << 0)
    public static let interactions = GetOptions(rawValue: 1 << 1)
    public static let aggregates   = GetOptions(rawValue: 1 << 2)

    public static let all: GetOptions = [.object, .interactions, .aggregates]
}
