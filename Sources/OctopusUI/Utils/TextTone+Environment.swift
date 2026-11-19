//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

private struct TextToneKey: EnvironmentKey {
    static let defaultValue: TextTone = .formal
}

extension EnvironmentValues {
    /// The tone of the SDK texts for the member, injected by the SDK's entry screens. Formal outside of them (in
    /// previews, for instance), which is the text every community showed before the tone could be set.
    var textTone: TextTone {
        get { self[TextToneKey.self] }
        set { self[TextToneKey.self] = newValue }
    }
}

extension TextTone {
    /// The key of the version of a text that matches this tone.
    ///
    /// Both keys are written in full at the call site, so that Xcode sees each of them used in the string catalog.
    func key(formal: LocalizedStringKey, informal: LocalizedStringKey) -> LocalizedStringKey {
        switch self {
        case .formal: formal
        case .informal: informal
        }
    }

    /// The key of the version of a text that matches this tone, for the APIs that look a key up by its name
    /// (`L10n`, `Bundle.localizedString(forKey:value:table:)`).
    func stringKey(formal: String, informal: String) -> String {
        switch self {
        case .formal: formal
        case .informal: informal
        }
    }
}

extension OctopusSDK {
    /// The tone of the SDK texts for the member right now, for the code that resolves a text outside of a view
    /// (a VoiceOver announcement, for instance). Views read `EnvironmentValues.textTone` instead.
    var textTone: TextTone {
        TextTone(config: core.configRepository.communityConfig,
                 languageIdentifier: core.languageRepository.localeIdentifier)
    }
}

/// Observes the language manager to keep `textTone` up to date in the environment of `content`.
struct TextToneEnvironment: ViewModifier {
    @ObservedObject var languageManager: LanguageManager

    func body(content: Content) -> some View {
        content.environment(\.textTone, languageManager.textTone)
    }
}
