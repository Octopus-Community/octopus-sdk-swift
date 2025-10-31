//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


import Foundation
import SwiftUI
import Combine
import OctopusCore

final class ContentTranslationPreferenceStore: ObservableObject {
    /// Dictionary mapping content IDs to a Boolean.
    /// Only here to update the Observable object
    @Published private var contentDisplayTranslations: [String: Bool] = [:]

    private let repository: ContentTranslationPreferenceRepository
    private var storage = [AnyCancellable]()

    init(repository: ContentTranslationPreferenceRepository) {
        self.repository = repository
        repository.$contentDisplayTranslations.sink { [unowned self] in
            contentDisplayTranslations = $0
        }.store(in: &storage)
    }

    /// Returns whether the given content should display the original text.
    func displayTranslation(for contentId: String) -> Bool {
        repository.displayTranslation(for: contentId)
    }

    /// Toggles the display mode for a given content ID.
    /// - Returns: the new display translation value
    @discardableResult
    func toggleDisplayTranslation(for contentId: String) -> Bool {
        return repository.toggleDisplayTranslation(for: contentId)
    }
}
