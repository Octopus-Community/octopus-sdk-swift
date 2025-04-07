//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


import Foundation
import OctopusCore
import Combine

struct DisplayablePoll: Equatable {
    struct Option: Sendable, Equatable {
        let id: String
        let text: String
    }
    let options: [Option]
}

extension DisplayablePoll {
    init(from poll: Poll) {
        options = poll.options.prefix(7).map { Option(id: $0.id, text: $0.text) }
    }
}
