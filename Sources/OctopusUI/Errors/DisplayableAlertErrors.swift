//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// An error that can be displayed in an alert
enum DisplayableString: Equatable {
    /// The string is already in the correct locale
    case localizedString(String)
    /// The error string is a localized string key
    case localizationKey(LocalizedStringKey)
    /// A text that addresses the member: one localized string key per tone, the displayed one being the key of the
    /// member's tone.
    case tonedKey(formal: LocalizedStringKey, informal: LocalizedStringKey)
}

extension DisplayableString {
    /// The generic error message.
    static var unknownError: DisplayableString {
        .tonedKey(formal: "Error.Unknown.Formal", informal: "Error.Unknown.Informal")
    }
    /// The error message of a call that failed for lack of network.
    static var noNetworkError: DisplayableString {
        .tonedKey(formal: "Error.NoNetwork.Formal", informal: "Error.NoNetwork.Informal")
    }
    /// The error message of an action the server refused without saying why.
    static var permissionDeniedError: DisplayableString {
        .tonedKey(formal: "Error.PermissionDenied.Formal", informal: "Error.PermissionDenied.Informal")
    }

    /// The error message of a text longer than allowed.
    static func textTooLongError(currentLength: Int, maxLength: Int) -> DisplayableString {
        .tonedKey(formal: "Error.Text.TooLong.Formal_currentLength:\(currentLength)_maxLength:\(maxLength)",
                  informal: "Error.Text.TooLong.Informal_currentLength:\(currentLength)_maxLength:\(maxLength)")
    }

    /// The error message of a picture whose size or ratio is refused.
    static func pictureSelectionError(maxRatio: String, minSize: Int) -> DisplayableString {
        .tonedKey(formal: "Picture.Selection.Error.Formal_maxRatio:\(maxRatio)_minSize:\(minSize)",
                  informal: "Picture.Selection.Error.Informal_maxRatio:\(maxRatio)_minSize:\(minSize)")
    }
}

/// Extension of DisplayableAlertError that adds useful funtions for SwiftUI views
extension DisplayableString {
    /// - Parameter tone: the member's tone (`EnvironmentValues.textTone`), which picks the key of a `tonedKey`.
    func textView(tone: TextTone) -> Text {
        switch self {
        case let .localizedString(message):
            Text(message)
        case let .localizationKey(message):
            Text(message, bundle: .module)
        case let .tonedKey(formal, informal):
            Text(tone.key(formal: formal, informal: informal), bundle: .module)
        }
    }

    /// - Parameter tone: the member's tone (`EnvironmentValues.textTone`), which picks the key of a `tonedKey`.
    func localizedString(locale: Locale?, tone: TextTone) -> String {
        let key: LocalizedStringKey
        switch self {
        case let .localizedString(message):
            return message
        case let .localizationKey(message):
            key = message
        case let .tonedKey(formal, informal):
            key = tone.key(formal: formal, informal: informal)
        }
        guard let stringKey = key.stringKey else {
            return ""
        }
        return L10n(stringKey, locale: locale)
    }
}

extension Array where Element == DisplayableString {
    func textView(tone: TextTone) -> Text {
        self.enumerated()
            .map { index, displayableString in
                if index < self.count - 1 {
                    displayableString.textView(tone: tone) + Text(verbatim: ", ")
                } else {
                    displayableString.textView(tone: tone)
                }
            }
            .reduce(Text(verbatim: ""), +)
    }
}

extension LocalizedStringKey {

    // This will mirror the `LocalizedStringKey` so it can access its
    // internal `key` property. Mirroring is rather expensive, but it
    // should be fine performance-wise, unless you are
    // using it too much or doing something out of the norm.
    var stringKey: String? {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String
    }
}
