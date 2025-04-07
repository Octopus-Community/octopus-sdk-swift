//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public extension Validators {
    class Poll {
        public enum OptionTextError: Error {
            case tooShort
            case tooLong
        }

        public let minOptions = 2
        public let maxOptions = 7
        public let optionTextMaxLength = 100

        public func validate(pollOptionText: String) -> OptionTextError? {
            guard !pollOptionText.isEmpty else { return .tooShort }
            guard pollOptionText.count <= optionTextMaxLength else { return .tooLong }
            return nil
        }

        public func validate(_ option: WritablePoll.Option) -> Bool {
            return validate(pollOptionText: option.text) == nil
        }

        public func validate(_ poll: WritablePoll) -> Bool {
            guard poll.options.count >= minOptions && poll.options.count <= maxOptions else { return false }
            return poll.options.allSatisfy(validate(_:))
        }
    }
}
