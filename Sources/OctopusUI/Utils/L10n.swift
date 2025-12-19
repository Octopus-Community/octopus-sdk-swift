//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

/// Transforms a localized key into a localized string (taken from the module bundle)
/// - Parameter key: the key (can be found in Localizable.xcstrings)
/// - Returns: a localized string
/// - Note: This can be useful when the SwiftUI view has no API to set the bundle. However, it should be avoided
///   because it disables the Localizable.xcstrings file capacity to point to the line where the string is used.
func L10n(_ key: String, _ args: any CVarArg...) -> String {
    String.localizedStringWithFormat(Bundle.module.localizedString(forKey: key, value: nil, table: nil), args)
}
