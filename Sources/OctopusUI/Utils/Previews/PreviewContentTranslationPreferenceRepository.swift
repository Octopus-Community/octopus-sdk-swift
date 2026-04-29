//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

class PreviewContentTranslationPreferenceRepository: ContentTranslationPreferenceRepository {
    public var contentDisplayTranslationsPublisher: AnyPublisher<[String: Bool], Never> {
        $contentDisplayTranslations.eraseToAnyPublisher()
    }

    /// Dictionary mapping content IDs to a Boolean:
    /// - true = show translation text
    /// - false = show original text
    /// - nil = show translation text
    @Published private(set) var contentDisplayTranslations: [String: Bool] = [:]

    /// Returns whether the given content should display the original text.
    public func displayTranslation(for contentId: String) -> Bool {
        contentDisplayTranslations[contentId] ?? true
    }

    /// Toggles the display mode for a given content ID.
    /// - Returns: the new display translation value
    @discardableResult
    public func toggleDisplayTranslation(for contentId: String) -> Bool {
        let current = contentDisplayTranslations[contentId] ?? true
        let newValue = !current
        contentDisplayTranslations[contentId] = newValue

        return newValue
    }
}
