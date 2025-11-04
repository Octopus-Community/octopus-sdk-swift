//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct Poll: Sendable, Equatable {
    public struct Option: Sendable, Equatable {
        public let id: String
        public let text: TranslatableText
    }
    public let options: [Option]
}

extension Poll {
    init?(from options: [PollOptionEntity]?) {
        guard let options else { return nil }
        self.options = options.map {
            Option(id: $0.uuid, text: TranslatableText(originalText: $0.text, originalLanguage: nil,
                                                       translatedText: $0.translatedText))
        }
    }

    init?(from poll: Com_Octopuscommunity_Poll) {
        guard !poll.answers.isEmpty else { return nil }
        self.options = poll.answers.map {
            Option(id: $0.id, text: TranslatableText(originalText: $0.text, originalLanguage: nil,
                                                     translatedText: $0.translatedText))
        }
    }
}
