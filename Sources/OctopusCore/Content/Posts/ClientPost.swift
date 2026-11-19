//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import CryptoKit
import Accelerate

/// An Octopus Post that is linked to a client object (article, product...).
public struct ClientPost: Sendable, Encodable {
    public enum Attachment: Sendable {
        case localImage(Data)
        case distantImage(URL)

        /// The value of this media in the signature hash: the URL, or the bytes in URL-safe Base64 without padding.
        fileprivate var signatureValue: String {
            switch self {
            case .distantImage(let url):
                url.absoluteString
            case .localImage(let data):
                data.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
        }

        /// Adds ``signatureValue`` to `hasher` without building it in one piece: the URL as `encoder` escapes it in
        /// the JSON, or the bytes in URL-safe Base64 without padding, 48 KB of bytes at a time.
        fileprivate func updateSignature(of hasher: inout SHA256, encoder: JSONEncoder) throws {
            switch self {
            case .distantImage(let url):
                let quoted = try encoder.encode(url.absoluteString)
                hasher.update(data: quoted.dropFirst().dropLast())
            case .localImage(let data):
                // A multiple of 3: every chunk but the last encodes to Base64 without padding.
                let chunkSize = 48 * 1024
                var offset = data.startIndex
                while offset < data.endIndex {
                    let end = min(offset + chunkSize, data.endIndex)
                    var base64 = data[offset..<end].base64EncodedData()
                    Self.makeURLSafe(&base64)
                    if end == data.endIndex, let padding = base64.firstIndex(of: UInt8(ascii: "=")) {
                        base64 = base64[..<padding]
                    }
                    hasher.update(data: base64)
                    offset = end
                }
            }
        }

        /// Maps every byte to itself, except the two characters of the standard Base64 alphabet that the URL-safe
        /// one replaces.
        private static let urlSafeBase64Table: [Pixel_8] = (0...255).map { byte in
            switch UInt8(byte) {
            case UInt8(ascii: "+"): UInt8(ascii: "-")
            case UInt8(ascii: "/"): UInt8(ascii: "_")
            default: UInt8(byte)
            }
        }

        /// Turns standard Base64 into its URL-safe alphabet, in place.
        ///
        /// A table lookup of Accelerate rather than a loop over the bytes: the SDK is built in the app's configuration,
        /// and in Debug a Swift loop over tens of MB of Base64 takes seconds, where Accelerate stays optimized.
        private static func makeURLSafe(_ base64: inout Data) {
            let count = base64.count
            guard count > 0 else { return }
            base64.withUnsafeMutableBytes { bytes in
                var buffer = vImage_Buffer(data: bytes.baseAddress, height: 1, width: vImagePixelCount(count),
                                           rowBytes: count)
                _ = vImageTableLookUp_Planar8(&buffer, &buffer, urlSafeBase64Table, vImage_Flags(kvImageNoFlags))
            }
        }
    }
    /// An id that uniquely identifies the object linked to this post. It will be used to retrieve the post if it
    /// already exists and in the `displayClientObject` callback.
    public let clientObjectId: String
    /// The topic id to save your post to. If nil, a default topic that you should configure with our backend team will
    /// be used.
    public let groupId: String?
    /// The text of the post. Length must be between 10 and 5000 characters.
    public let text: String
    /// The catch phrase. You can use something like "What do you think about this?". It will be displayed below the
    /// text, in bold. Must be below 84 characters. We recommand between 6 and 38 characters.
    /// If nil, it won't be displayed.
    public let catchPhrase: String?
    /// The medias of the post, in display order. Each one can be a local image as Data or a distant image as URL.
    public internal(set) var medias: [Attachment]
    /// The text that will be displayed in a button to display your object. When the button containing this text will
    /// be tapped, the `displayClientObject` callback will be called with your object id.
    /// Must be below 28 characters. We recommand between 4 and 28 characters.
    public let viewClientObjectButtonText: String?
    /// The labels of the button given per language, `viewClientObjectButtonText` being the one of their default
    /// language. `nil` when the text is translated automatically.
    public let viewClientObjectButtonLabels: PerLanguageLabels?
    /// When set, the signature JSON holds this string in place of the `ctaTextTranslations` object: the hash
    /// swaps it for the object written with its keys in the signed order.
    private var signedTranslationsPlaceholder: String?
    /// A token signed to ensure the request comes from an authorized requester.
    public let signature: String?

    public init(clientObjectId: String,
                groupId: String?,
                text: String,
                catchPhrase: String?,
                medias: [Attachment],
                viewClientObjectButtonText: String?,
                viewClientObjectButtonLabels: PerLanguageLabels? = nil,
                signature: String? = nil) {
        self.clientObjectId = clientObjectId
        self.groupId = groupId
        self.text = text
        self.catchPhrase = catchPhrase
        self.medias = medias
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.viewClientObjectButtonLabels = viewClientObjectButtonLabels
        self.signature = signature
    }

    private enum CodingKeys: String, CodingKey {
        case clientObjectId
        case topicId // Need to be topicId in the computation of the sha1
        case text
        case catchPhrase
        case image
        case ctaText
        case ctaTextLanguage
        case ctaTextTranslations
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(clientObjectId, forKey: .clientObjectId)
        try container.encodeIfPresent(groupId, forKey: .topicId)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(catchPhrase, forKey: .catchPhrase)
        // The signature hash keeps a single `image` key: the value of every media, in order, joined by ", ". A post
        // with one media therefore keeps the hash it had when it could only carry one.
        if !medias.isEmpty {
            try container.encode(medias.map(\.signatureValue).joined(separator: ", "), forKey: .image)
        }
        try container.encodeIfPresent(viewClientObjectButtonText, forKey: .ctaText)
        // Left out without per-language labels: such a post keeps the hash it always had.
        if viewClientObjectButtonText != nil, let labels = viewClientObjectButtonLabels {
            try container.encode(labels.defaultLanguageCode, forKey: .ctaTextLanguage)
            // The translations are only written as the placeholder that `getHashForSignature` swaps for the
            // object in the signed key order: the encoder would sort its keys in an order that depends on the OS
            // version.
            if let signedTranslationsPlaceholder {
                try container.encode(signedTranslationsPlaceholder, forKey: .ctaTextTranslations)
            }
        }
    }

    /// The SHA-256, in hexadecimal, of the post encoded in JSON with sorted keys and unescaped slashes.
    ///
    /// The images can weigh tens of MB, and their Base64 a third more: the JSON is not built in one piece. It is
    /// encoded with a marker in place of the `image` value, then hashed up to the marker, the medias one after the
    /// other, and the rest. The hash is the same as the one of the whole JSON.
    ///
    /// The `ctaTextTranslations` object is not left to the encoder either: its sorted keys do not follow the signed
    /// order on every OS version (see `PerLanguageLabels.signedTranslationsJSON`). It is encoded as a placeholder
    /// string, which is then swapped for the object written by hand.
    func getHashForSignature() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard !medias.isEmpty else {
            return Self.hexadecimal(SHA256.hash(data: try Self.signatureJson(of: self, encoder: encoder)))
        }
        // A fresh UUID cannot appear anywhere else in the JSON, and is encoded as it is.
        let marker = UUID().uuidString
        var withMarker = self
        withMarker.medias = [.distantImage(URL(string: marker)!)]
        let json = try Self.signatureJson(of: withMarker, encoder: encoder)
        guard let markerRange = json.range(of: Data(marker.utf8)) else { throw InternalError.objectMalformed }

        var hasher = SHA256()
        hasher.update(data: json[..<markerRange.lowerBound])
        for (index, media) in medias.enumerated() {
            if index > 0 { hasher.update(data: Data(", ".utf8)) }
            try media.updateSignature(of: &hasher, encoder: encoder)
        }
        hasher.update(data: json[markerRange.upperBound...])
        return Self.hexadecimal(hasher.finalize())
    }

    /// The JSON of `post` that is hashed, with its `ctaTextTranslations` object in the signed key order.
    private static func signatureJson(of post: ClientPost, encoder: JSONEncoder) throws -> Data {
        guard post.viewClientObjectButtonText != nil,
              let translations = try post.viewClientObjectButtonLabels?.signedTranslationsJSON(encoder: encoder)
        else {
            return try encoder.encode(post)
        }
        // A fresh UUID cannot appear anywhere else in the JSON, and is encoded as it is.
        let placeholder = UUID().uuidString
        var withPlaceholder = post
        withPlaceholder.signedTranslationsPlaceholder = placeholder
        var json = try encoder.encode(withPlaceholder)
        guard let range = json.range(of: Data("\"\(placeholder)\"".utf8)) else {
            throw InternalError.objectMalformed
        }
        json.replaceSubrange(range, with: translations)
        return json
    }

    private static func hexadecimal(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension ClientPost {
    /// The local images of `medias`, in order: the ones to upload before creating the post.
    var localImages: [Data] {
        medias.compactMap {
            guard case let .localImage(data) = $0 else { return nil }
            return data
        }
    }

    /// The post to send when its local images were uploaded beforehand: they are referenced by upload id, the
    /// distant ones keep their url.
    /// - Parameter uploadIds: the upload id of each local image of `medias`, in the same order (see `localImages`).
    /// - Throws: `InternalError.objectMalformed` when `uploadIds` does not hold exactly one id per local image: the
    ///   post would otherwise carry an image without any file.
    func rwOctoPost(uploadIds: [String]) throws -> Com_Octopuscommunity_Post {
        guard uploadIds.count == localImages.count else { throw InternalError.objectMalformed }
        var uploadIds = uploadIds[...]
        return rwOctoPost { media in
            .with {
                switch media {
                case .localImage:
                    // The count was checked above: there is one id left for each local image.
                    $0.uploadID = uploadIds.removeFirst()
                    $0.isOptimized = true
                case let .distantImage(imageUrl):
                    $0.file = .url(imageUrl.absoluteString)
                }
            }
        }
    }

    /// The post to send with its local images inline, as bytes.
    /// - Parameter imagesAreCompressed: for each media of `medias`, in the same order, whether its bytes were
    ///   compressed (the `isOptimized` flag sent to the server). Ignored for distant images; a missing entry means
    ///   not compressed.
    func rwOctoPost(imagesAreCompressed: [Bool]) -> Com_Octopuscommunity_Post {
        var index = -1
        return rwOctoPost { media in
            index += 1
            return .with {
                switch media {
                case let .localImage(imageData):
                    $0.file = .bytes(imageData)
                    $0.isOptimized = imagesAreCompressed.indices.contains(index)
                        && imagesAreCompressed[index]
                case let .distantImage(imageUrl):
                    $0.file = .url(imageUrl.absoluteString)
                }
            }
        }
    }

    /// - Parameter image: builds the proto image of a media. Called once per media, in order.
    private func rwOctoPost(image: (Attachment) -> Com_Octopuscommunity_Image) -> Com_Octopuscommunity_Post {
        .with {
            $0.text = text
            if !medias.isEmpty {
                $0.media = .with {
                    $0.images = medias.map(image)
                }
            }
            $0.bridgeToClientObject = .with {
                $0.clientObjectID = clientObjectId
                if let catchPhrase {
                    $0.catchPhrase = catchPhrase
                }
                if let viewClientObjectButtonText {
                    $0.cta = .with {
                        $0.text = viewClientObjectButtonText
                        viewClientObjectButtonLabels?.fill(&$0)
                    }
                }
            }
        }
    }
}
