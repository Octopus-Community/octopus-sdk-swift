//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// Settings › Language: "Follow system", then the Android sample's languages in its order. It changes the SDK
/// only, through `overrideDefaultLocale(with:)`; the sample itself stays in English.
@MainActor
final class LanguageSettingsViewModel: ObservableObject {
    /// One row: `nil` language is "Follow system".
    struct Option: Identifiable, Equatable {
        let language: SDKLanguage?

        var id: String { language?.code ?? "system" }
        var title: String { language?.name ?? "Follow system" }
        var accessibilityId: String { "language-option-\(id)" }
    }

    let options: [Option] = [Option(language: nil)] + SDKLanguages.settingsList.map { Option(language: $0) }

    /// The locale identifier currently forced on the SDK, `nil` when it follows the system.
    @Published private(set) var selectedIdentifier: String?

    private let apply: (Locale?) -> Void
    private var storage = [AnyCancellable]()

    /// - Parameters:
    ///   - current: the override in place, followed while the screen is open.
    ///   - apply: forwards a choice to the SDK. Both injected by the tests; the app uses `SampleLanguageManager`.
    init(current: AnyPublisher<Locale?, Never> = SampleLanguageManager.instance.$overriddenLocale.eraseToAnyPublisher(),
         apply: @escaping (Locale?) -> Void = { SampleLanguageManager.instance.set(locale: $0) }) {
        self.apply = apply
        current
            .map { $0?.identifier }
            .sink { [weak self] in self?.selectedIdentifier = $0 }
            .store(in: &storage)
    }

    func isSelected(_ option: Option) -> Bool {
        option.language?.code == selectedIdentifier
    }

    func select(_ option: Option) {
        selectedIdentifier = option.language?.code
        apply(option.language?.locale)
    }
}
