//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Different kind of how to handle URL opening
public enum URLOpeningStrategy {
    /// The url is handled by the app. It means that you, as a developer, take care of handling this URL and opening
    /// a screen, a website, an app or something else with it
    case handledByApp
    /// The url is handled by Octopus Community. It will be opened in an external web browser using
    /// `UIApplication.shared.open(url)`.
    case handledByOctopus
}
