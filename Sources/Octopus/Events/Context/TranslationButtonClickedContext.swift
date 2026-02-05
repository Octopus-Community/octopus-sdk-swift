//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .translationButtonClicked
    public protocol TranslationButtonClickedContext: Sendable {
        /// The id of the content
        var contentId: String { get }
        /// Whether the user wants to display the translated or the original content
        var viewTranslated: Bool { get }
        /// The kind of content
        var contentKind: ContentKind { get }
    }
}

extension SdkEvent.TranslationButtonClickedContext: OctopusEvent.TranslationButtonClickedContext {
    public var contentKind: OctopusEvent.ContentKind { .init(from: coreContentKind) }
}
