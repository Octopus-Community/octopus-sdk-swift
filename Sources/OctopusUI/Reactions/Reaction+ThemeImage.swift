//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit
import OctopusCore

extension OctopusTheme.Assets.Icons.Content.Reaction {
    /// Returns the image for the given reaction kind.
    /// For `.unknown` kinds (forward-compatibility), generates an image from the emoji string.
    subscript(kind: ReactionKind) -> UIImage {
        switch kind {
        case .heart: return heart
        case .joy: return joy
        case .mouthOpen: return mouthOpen
        case .clap: return clap
        case .cry: return cry
        case .rage: return rage
        case .unknown(let unicode): return Self.imageFromEmoji(unicode)
        }
    }

    private static func imageFromEmoji(_ emoji: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: 32)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (emoji as NSString).size(withAttributes: attributes)
        guard size.width > 0, size.height > 0 else { return UIImage() }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            (emoji as NSString).draw(at: .zero, withAttributes: attributes)
        }
    }
}
