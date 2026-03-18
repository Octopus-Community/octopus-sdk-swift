//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// The title displayed in the navigation bar on the main feed screen
public struct OctopusMainFeedTitle {
    public enum Content {
        /// A text title
        public struct TextTitle {
            /// The text to display. To have better UI results, please keep it as little as possible as it will be
            /// displayed on one line (no more than 18 chars)
            public let text: String

            /// Constructor
            /// - Parameter text: The text to display.
            ///                   To have better UI results, please keep it as little as possible as it will be
            ///                   displayed on one line (no more than 18 chars)
            public init(text: String) {
                self.text = text
            }
        }

        /// The title will be the `logo` you provided in the Theme.
        /// If you did not provide a custom logo in the OctopusTheme, this will be ignored and the item will be empty.
        case logo
        /// The title will be the text you provide.
        /// To have better UI results, please keep the text as little as possible as it will be
        /// displayed on one line (no more than 18 chars)
        case text(TextTitle)
    }

    /// The position of the title
    public enum Placement {
        /// The title will be displayed at the leading place (i.e. at the left on left to right languages)
        case leading
        /// The title will be centered
        case center
    }

    /// The content of the title
    public let content: Content
    /// The place of the title
    public let placement: Placement
    
    /// Constructor of a main feed title
    /// - Parameters:
    ///   - content: the content of the title.
    ///     It is either `.logo` to display the logo provided in the OctopusTheme. If you do not provided a custom logo,
    ///     the title will be empty.
    ///   - placement: the position of the title
    public init(content: Content, placement: Placement) {
        self.content = content
        self.placement = placement
    }
}
