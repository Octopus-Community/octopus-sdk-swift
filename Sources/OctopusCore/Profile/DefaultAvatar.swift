//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// What to draw for a member who has no picture of their own, as chosen by the community.
///
/// Wherever it is optional, `nil` means the app computes the avatar itself (the member's initials on a color derived
/// from their nickname). That is also the fallback for any value this version cannot draw.
public enum DefaultAvatar: Equatable, Sendable {
    /// The member's initials in `initialsHex`, on `backgroundHex`. Both are `#RRGGBB`. The server picks the initials
    /// color for contrast, and the pair is the same in light and dark mode.
    case color(backgroundHex: String, initialsHex: String)
    /// An image to draw like a profile picture. A new image always comes with a new URL.
    case image(url: URL)
}

extension DefaultAvatar {
    /// `nil` when the message holds no kind this version knows, or a value that cannot be drawn.
    init?(from proto: Com_Octopuscommunity_DefaultAvatar) {
        switch proto.kind {
        case let .color(color):
            self.init(backgroundHex: color.backgroundHex, initialsHex: color.initialsHex, imageUrl: nil)
        case let .imageURL(imageUrl):
            self.init(backgroundHex: nil, initialsHex: nil, imageUrl: imageUrl)
        case .none:
            return nil
        }
    }

    /// Rebuilds the value from its stored form (see `backgroundHex`, `initialsHex`, `imageUrl`). `nil` when that form
    /// holds nothing that can be drawn.
    init?(backgroundHex: String?, initialsHex: String?, imageUrl: String?) {
        if let backgroundHex, let initialsHex, Self.isValidHex(backgroundHex), Self.isValidHex(initialsHex) {
            self = .color(backgroundHex: backgroundHex, initialsHex: initialsHex)
        } else if let imageUrl = imageUrl?.nilIfEmpty, let url = URL(string: imageUrl),
                  ["http", "https"].contains(url.scheme?.lowercased()), url.host?.isEmpty == false {
            self = .image(url: url)
        } else {
            return nil
        }
    }

    /// The background color of `.color`, `nil` otherwise.
    public var backgroundHex: String? {
        switch self {
        case let .color(backgroundHex, _): return backgroundHex
        case .image: return nil
        }
    }

    /// The initials color of `.color`, `nil` otherwise.
    public var initialsHex: String? {
        switch self {
        case let .color(_, initialsHex): return initialsHex
        case .image: return nil
        }
    }

    /// The URL of `.image`, `nil` otherwise.
    public var imageUrl: URL? {
        switch self {
        case .color: return nil
        case let .image(url): return url
        }
    }

    /// Whether `hex` is `#RRGGBB` (ASCII hex digits only).
    private static func isValidHex(_ hex: String) -> Bool {
        hex.count == 7 && hex.first == "#" && hex.dropFirst().allSatisfy { $0.isASCII && $0.isHexDigit }
    }
}
