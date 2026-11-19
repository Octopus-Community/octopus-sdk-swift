//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The sentence that tells a banned member who to write to in order to appeal.
enum CommunityAccessDeniedBanAppeal {
    /// The sentence cut around the address, which is displayed as a link.
    struct Parts: Equatable {
        let before: String
        /// Empty when the sentence does not hold the address.
        let email: String
        let after: String
    }

    /// Cuts `sentence` around `email`. When the sentence does not hold the address (a translation that dropped its
    /// parameter), it is kept whole in `before`.
    static func parts(sentence: String, email: String) -> Parts {
        guard !email.isEmpty, let range = sentence.range(of: email) else {
            return Parts(before: sentence, email: "", after: "")
        }
        return Parts(before: String(sentence[..<range.lowerBound]), email: email,
                     after: String(sentence[range.upperBound...]))
    }

    /// The URL that opens a mail to `email`, `nil` when the address gives none. The address is typed by the
    /// community: whatever it holds is escaped rather than trusted.
    static func mailtoURL(for email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "mailto:\(escaped)")
    }
}
