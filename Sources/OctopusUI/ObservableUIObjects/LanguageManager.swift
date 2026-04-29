//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

@MainActor
final class LanguageManager: ObservableObject {
    @Published private(set) var overridenLocale: Locale?

    private var storage = [AnyCancellable]()

    /// Designated init. Accepts the locale publisher directly so previews/tests can inject a
    /// fixed or scripted sequence without requiring a full `OctopusSDK`.
    init(overridenLocalePublisher: AnyPublisher<Locale?, Never>) {
        overridenLocalePublisher
            .sink { [unowned self] in overridenLocale = $0 }
            .store(in: &storage)
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        self.init(overridenLocalePublisher:
            octopus.core.languageRepository.$overridenLocale.eraseToAnyPublisher())
    }

    /// Preview factory — emits `nil` immediately and never updates.
    static func forPreviews() -> LanguageManager {
        LanguageManager(overridenLocalePublisher: Just<Locale?>(nil).eraseToAnyPublisher())
    }
}
