//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public extension Validators {
    enum Poll {
        public enum OptionTextError: Error {
            case tooShort
            case tooLong
        }

        public static let minOptions = 2
        public static let maxOptions = 7
        public static let optionTextMaxLength = 100

        public static func validate(pollOptionText: String) -> OptionTextError? {
            guard !pollOptionText.isEmpty else { return .tooShort }
            guard pollOptionText.count <= optionTextMaxLength else { return .tooLong }
            return nil
        }

        public static func validate(_ option: WritablePoll.Option) -> Bool {
            return validate(pollOptionText: option.text) == nil
        }

        public static func validate(_ poll: WritablePoll) -> Bool {
            guard poll.options.count >= minOptions && poll.options.count <= maxOptions else { return false }
            return poll.options.allSatisfy(validate(_:))
        }
    }
}
