//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    func overrideLanguageIfNeeded(languageManager: LanguageManager) -> some View {
        self.modify {
            if let overridenLocale = languageManager.overridenLocale {
                $0.environment(\.locale, overridenLocale)
            } else { $0 }
        }
    }
}
