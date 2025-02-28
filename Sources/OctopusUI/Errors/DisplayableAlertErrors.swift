//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// An error that can be displayed in an alert
enum DisplayableString: Equatable {
    /// The string is already in the correct locale
    case localizedString(String)
    /// The error string is a localized string key
    case localizationKey(LocalizedStringKey)
}

/// Extension of DisplayableAlertError that adds useful funtions for SwiftUI views
extension DisplayableString {
    var textView: Text {
        switch self {
        case let .localizedString(message):
            Text(message)
        case let .localizationKey(message):
            Text(message, bundle: .module)
        }
    }
}

extension Array where Element == DisplayableString {
    var textView: Text {
        self.enumerated()
            .map { index, displayableString in
                if index < self.count - 1 {
                    displayableString.textView + Text(verbatim: ", ")
                } else {
                    displayableString.textView
                }
            }
            .reduce(Text(verbatim: ""), +)
    }
}
