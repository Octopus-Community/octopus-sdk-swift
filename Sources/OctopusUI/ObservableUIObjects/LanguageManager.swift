//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

@MainActor
final class LanguageManager: ObservableObject {
    @Published private(set) var overridenLocale: Locale?
    /// The tone of the SDK texts in the language they are displayed in, from the community config.
    @Published private(set) var textTone: TextTone = .formal

    private var storage = [AnyCancellable]()

    /// Designated init. Accepts the publishers directly so previews/tests can inject a fixed or scripted sequence
    /// without requiring a full `OctopusSDK`.
    init(overridenLocalePublisher: AnyPublisher<Locale?, Never>,
         textTonePublisher: AnyPublisher<TextTone, Never> = Just(.formal).eraseToAnyPublisher()) {
        overridenLocalePublisher
            .sink { [unowned self] in overridenLocale = $0 }
            .store(in: &storage)
        textTonePublisher
            .removeDuplicates()
            .sink { [unowned self] in textTone = $0 }
            .store(in: &storage)
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        let languageRepository = octopus.core.languageRepository
        self.init(
            overridenLocalePublisher: languageRepository.$overridenLocale.eraseToAnyPublisher(),
            textTonePublisher: Self.textTone(
                informalLanguages: octopus.core.configRepository.communityConfigPublisher
                    .map { $0?.informalLanguages ?? [] }
                    .eraseToAnyPublisher(),
                languageIdentifier: languageRepository.$localeIdentifier.eraseToAnyPublisher()))
    }

    /// The tone, recomputed whenever the community config or the displayed language changes.
    static func textTone(informalLanguages: AnyPublisher<[String], Never>,
                         languageIdentifier: AnyPublisher<String, Never>) -> AnyPublisher<TextTone, Never> {
        Publishers.CombineLatest(informalLanguages, languageIdentifier)
            .map { TextTone(informalLanguages: $0, languageIdentifier: $1) }
            .eraseToAnyPublisher()
    }

    /// Preview factory — emits `nil` immediately and never updates.
    static func forPreviews() -> LanguageManager {
        LanguageManager(overridenLocalePublisher: Just<Locale?>(nil).eraseToAnyPublisher())
    }
}
