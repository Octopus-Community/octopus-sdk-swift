//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public struct CustomAction: Equatable, Sendable {
    public let ctaText: TranslatableText
    public let targetUrl: URL

    public init(ctaText: TranslatableText, targetUrl: URL) {
        self.ctaText = ctaText
        self.targetUrl = targetUrl
    }

    /// Failable convenience init enforcing PRD Rules 2 and 3:
    /// both fields must be present, `ctaText.originalText` must be non-empty (TranslatableText
    /// already trims whitespace at init time), and `targetLink` must parse via `URL(string:)`.
    /// Returns nil otherwise.
    public init?(ctaText: TranslatableText?, targetLink: String?) {
        guard let ctaText, !ctaText.originalText.isEmpty,
              let targetLink, let targetUrl = URL(string: targetLink) else {
            return nil
        }
        self.init(ctaText: ctaText, targetUrl: targetUrl)
    }
}
