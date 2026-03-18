//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import CryptoKit

/// An Octopus Post that is linked to a client object (article, product...).
public struct ClientPost: Sendable, Encodable {
    public enum Attachment: Sendable {
        case localImage(Data)
        case distantImage(URL)
    }
    /// An id that uniquely identifies the object linked to this post. It will be used to retrieve the post if it
    /// already exists and in the `displayClientObject` callback.
    public let clientObjectId: String
    /// The topic id to save your post to. If nil, a default topic that you should configure with our backend team will
    /// be used.
    public let topicId: String?
    /// The text of the post. Length must be between 10 and 5000 characters.
    public let text: String
    /// The catch phrase. You can use something like "What do you think about this?". It will be displayed below the
    /// text, in bold. Must be below 84 characters. We recommand between 6 and 38 characters.
    /// If nil, it won't be displayed.
    public let catchPhrase: String?
    /// The attachment of the post. It can be a local image as Data or a distant image as URL.
    public internal(set) var attachment: Attachment?
    /// The text that will be displayed in a button to display your object. When the button containing this text will
    /// be tapped, the `displayClientObject` callback will be called with your object id.
    /// Must be below 28 characters. We recommand between 4 and 28 characters.
    public let viewClientObjectButtonText: String?
    /// A token signed to ensure the request comes from an authorized requester.
    public let signature: String?

    public init(clientObjectId: String,
                topicId: String?,
                text: String,
                catchPhrase: String?,
                attachment: Attachment?,
                viewClientObjectButtonText: String?,
                signature: String? = nil) {
        self.clientObjectId = clientObjectId
        self.topicId = topicId
        self.text = text
        self.catchPhrase = catchPhrase
        self.attachment = attachment
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.signature = signature
    }
    
    private enum CodingKeys: String, CodingKey {
        case clientObjectId
        case topicId
        case text
        case catchPhrase
        case image
        case ctaText
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientObjectId, forKey: .clientObjectId)
        try container.encodeIfPresent(topicId, forKey: .topicId)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(catchPhrase, forKey: .catchPhrase)
        if let attachment = attachment {
            switch attachment {
            case .distantImage(let url):
                try container.encode(url.absoluteString, forKey: .image)
            case .localImage(let data):
                let base64 = data.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                try container.encode(base64, forKey: .image)
            }
        }
        try container.encodeIfPresent(viewClientObjectButtonText, forKey: .ctaText)
    }

    func getHashForSignature() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = try encoder.encode(self)
        let hash = SHA256
            .hash(data: json)
            .map { String(format: "%02x", $0) }
            .joined()
        return hash
    }
}

extension ClientPost {
    func rwOctoPost(imageIsCompressed: Bool) -> Com_Octopuscommunity_Post {
        .with {
            $0.text = text
            switch attachment {
            case let .localImage(imageData):
                $0.media = .with {
                    $0.images = [
                        .with {
                            $0.file = .bytes(imageData)
                            $0.isOptimized = imageIsCompressed
                        }
                    ]
                }
            case let .distantImage(imageUrl):
                $0.media = .with {
                    $0.images = [
                        .with {
                            $0.file = .url(imageUrl.absoluteString)
                        }
                    ]
                }
            case .none: break
            }
            $0.bridgeToClientObject = .with {
                $0.clientObjectID = clientObjectId
                if let catchPhrase {
                    $0.catchPhrase = catchPhrase
                }
                if let viewClientObjectButtonText {
                    $0.cta = .with {
                        $0.text = viewClientObjectButtonText
                    }
                }
            }
        }
    }
}

