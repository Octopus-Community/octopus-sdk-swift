//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

/// View-local representation of a comment or reply. Used by the shared `ResponseView` in both
/// list (summary) and detail contexts.
struct ResponseViewData {
    let uuid: String
    let kind: ResponseKind
    let author: Author
    let relativeDate: String
    let text: EllipsizableTranslatedText?
    let image: ImageMedia?
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool
    let liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>
    let liveMeasuresValue: LiveMeasures
}
