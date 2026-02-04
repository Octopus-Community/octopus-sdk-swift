//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct TranslationButtonClickedContext: Sendable {
        /// The id of the content
        public let contentId: String
        /// Whether the user wants to display the translated or the original content
        public let viewTranslated: Bool
        /// The kind of content
        public let coreContentKind: ContentKind

        public init(contentId: String, viewTranslated: Bool, contentKind: ContentKind) {
            self.contentId = contentId
            self.viewTranslated = viewTranslated
            self.coreContentKind = contentKind
        }
    }
}
