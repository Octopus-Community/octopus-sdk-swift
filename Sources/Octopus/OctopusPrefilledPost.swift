//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import OctopusCore

/// A payload carrying content that prefills the Octopus post editor when
/// the host opens the SDK via `OctopusInitialScreen.createPost(...)`.
///
/// The host supplies any combination of text, images, topic and CTA; the
/// user can freely edit text, images and topic in the editor before
/// publishing. The CTA travels invisibly through the editor and is
/// attached to the published post.
///
/// The initializer reuses the same validation rules the editor enforces
/// at publish time (text length, image count and size/ratio), so integration bugs
/// surface during client-app QA instead of after the editor opens.
public struct OctopusPrefilledPost: Sendable {
    /// The text the editor opens with. Optional — `nil` (or `""`) opens the
    /// editor with no prefilled text, for the user to write themselves.
    public let text: String?

    /// Local image bytes (e.g. `UIImage(...).jpegData(...)`), in the order the editor shows them.
    /// The SDK does not fetch remote URLs — the host materializes the bytes before constructing
    /// this payload. Empty entries given to the initializer are dropped, so this list never holds
    /// empty `Data`, and it holds at most 10 images.
    public let images: [Data]

    /// Identifier of the group the post should land in. If `nil` or
    /// inaccessible, the user picks a group in the editor before
    /// publishing.
    public let topicId: String?

    /// Optional call-to-action button attached to the published post.
    /// Not displayed in the editor — the user cannot see, edit, or
    /// remove the CTA.
    public let cta: CTA?

    /// Optional closure signing the post so that its **images** are accepted in a community that
    /// forbids member pictures. When the member publishes a post carrying at least one image, the SDK
    /// computes a content fingerprint (SHA-256 of the post text, CTA and images) and calls this
    /// closure, whatever the community setting: only the server knows it for sure. Your closure
    /// returns a **compact JWS (JWT) signed HS256 with your shared secret**, carrying the
    /// `bridge_fingerprint` claim equal to the value the SDK passes in. Sign **on your backend** — the
    /// secret must never live in the app.
    ///
    /// Return `nil` when you cannot sign: the post is then sent unsigned and the server decides. A
    /// community that allows pictures publishes it with its images; one that forbids them refuses it
    /// and the editor shows an error. Throwing an error does not send the post: the editor stays open
    /// and shows an error, whatever the community setting.
    ///
    /// When the closure itself is `nil`, no token is attached, as when it returns `nil`.
    public let bridgeShareTokenProvider: (@Sendable (_ bridgeFingerprint: String) async throws -> String?)?

    /// Construct a prefilled-post payload.
    ///
    /// - Parameters:
    ///   - text: Initial text shown in the editor. Optional — `nil` and
    ///     `""` are equivalent (no prefilled text).
    ///   - images: Initial images shown in the editor, in display order, up to 10. Optional —
    ///     an empty list, and empty `Data` entries (which are dropped), mean no prefilled image.
    ///   - topicId: Identifier of the group to preselect.
    ///   - cta: Optional call-to-action attached to the published post.
    ///   - sign: Optional closure signing the content fingerprint, or returning `nil` to send the
    ///     post unsigned, see ``bridgeShareTokenProvider``.
    /// - Note: `text` and `images` are both optional; a payload with only a
    ///   `topicId` and/or `cta` (and empty content) opens the editor on the
    ///   preselected group with empty, user-editable fields.
    /// - Throws: `OctopusPrefilledPost.TooManyImagesError` if more than 10 non-empty images are
    ///   provided. `OctopusPrefilledPost.ValidationError` if the (provided) text length is out of
    ///   bounds, or an image cannot be decoded or violates size/ratio constraints (the first
    ///   failing image is reported).
    public init(text: String? = nil,
                images: [Data] = [],
                topicId: String? = nil,
                cta: CTA? = nil,
                sign: (@Sendable (_ bridgeFingerprint: String) async throws -> String?)? = nil) throws {
        let normalizedText: String? = (text?.isEmpty == true) ? nil : text
        let normalizedImages = images.filter { !$0.isEmpty }

        // Text and images are both optional: a Bridge Share can open the editor on a preselected
        // group (with an optional CTA) and empty, user-editable fields. Any provided text/image is
        // still validated below, and the editor re-validates the final content at publish time.

        // Match the editor's publish-time validation. A post text has no minimum beyond one character, so a
        // non-empty prefilled text is never too short; only the maximum length can reject it.
        if let normalizedText {
            switch Validators.Post.validate(
                text: normalizedText,
                hasPoll: false,
                ignoreTooShort: false
            ) {
            case .success: break
            // A whitespace-only text opens the editor as is; the editor keeps publishing disabled until the
            // member types something visible.
            case .failure(.empty): break
            case .failure(.tooShort):
                throw ValidationError.textTooShort(min: Validators.Post.minTextLength)
            case .failure(.tooLong):
                throw ValidationError.textTooLong(max: Validators.Post.maxTextLength)
            }
        }

        guard normalizedImages.count <= Validators.Post.maxImageCount else {
            throw TooManyImagesError(max: Validators.Post.maxImageCount, count: normalizedImages.count)
        }

        for imageData in normalizedImages {
            guard let uiImage = UIImage(data: imageData) else {
                throw ValidationError.imageInvalid
            }
            switch Validators.Picture.validate(uiImage) {
            case .valid: break
            case .sideTooSmall:
                throw ValidationError.imageTooSmall(min: Validators.Picture.minSize)
            case .ratioTooBig:
                throw ValidationError.imageRatioTooLarge(maxRatio: Validators.Picture.maxRatioStr)
            }
        }

        self.text = normalizedText
        self.images = normalizedImages
        self.topicId = topicId
        self.cta = cta
        self.bridgeShareTokenProvider = sign
    }

    /// Thrown by `OctopusPrefilledPost.init(text:images:topicId:cta:sign:)` when more images than
    /// a post can carry are provided. It is a separate type from ``ValidationError``, so catching
    /// `ValidationError` alone does not cover it. It is not a new `ValidationError` case because adding
    /// a case to that public enum would break the exhaustive `switch` statements integrators wrote on it.
    public struct TooManyImagesError: Error, Equatable, CustomDebugStringConvertible {
        /// The maximum number of images a post can carry.
        public let max: Int

        /// The number of (non-empty) images that were provided.
        public let count: Int

        /// Creates the error.
        ///
        /// - Parameters:
        ///   - max: The maximum number of images a post can carry.
        ///   - count: The number of (non-empty) images that were provided.
        public init(max: Int, count: Int) {
            self.max = max
            self.count = count
        }

        public var debugDescription: String {
            "OctopusPrefilledPost.TooManyImagesError: \(count) images provided, at most \(max) are accepted."
        }
    }

    /// A call-to-action button attached to the published post.
    public struct CTA: Sendable, Equatable {
        /// URL opened when the user taps the button. May be a custom
        /// scheme handled by the host's deeplink registration, an
        /// `https://` URL, or any other URL the OS knows how to route.
        public let url: URL

        /// Text shown on the button. When the label is given per language (see ``localizedLabel``), this is
        /// the label of the default language.
        public let label: String

        /// Text shown on the button, either translated automatically or given per language.
        public let localizedLabel: OctopusLocalizedText

        /// Construct a CTA.
        ///
        /// - Parameters:
        ///   - url: URL opened when the user taps the button.
        ///   - localizedLabel: Text shown on the button, either translated automatically
        ///     (`.autoTranslated("Start")`) or given per language
        ///     (`try .perLanguage([...], defaultLanguage:)`). Each label is recommended under 28 characters:
        ///     a longer one is displayed on one line, truncated.
        /// - Throws: `.ctaLabelEmpty` if the label is empty after
        ///   trimming whitespace; `.ctaUrlEmpty` if `url.absoluteString`
        ///   is empty.
        public init(url: URL, localizedLabel: OctopusLocalizedText) throws {
            guard !localizedLabel.defaultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.ctaLabelEmpty
            }
            guard !url.absoluteString.isEmpty else {
                throw ValidationError.ctaUrlEmpty
            }
            self.url = url
            self.label = localizedLabel.defaultText
            self.localizedLabel = localizedLabel
        }

        /// Construct a CTA whose label is translated automatically.
        ///
        /// - Parameters:
        ///   - url: URL opened when the user taps the button.
        ///   - label: Text shown on the button.
        /// - Throws: `.ctaLabelEmpty` if `label` is empty after
        ///   trimming whitespace; `.ctaUrlEmpty` if `url.absoluteString`
        ///   is empty.
        @available(*, deprecated, message: "Use init(url:localizedLabel:) with .autoTranslated(_:) to keep the automatic translation, or .perLanguage(_:defaultLanguage:) to give the label per language.")
        public init(url: URL, label: String) throws {
            try self.init(url: url, localizedLabel: .autoTranslated(label))
        }
    }

    /// Validation failures surfaced by `OctopusPrefilledPost.init` and
    /// `OctopusPrefilledPost.CTA.init`.
    #if hasAttribute(nonexhaustive)
    @nonexhaustive(warn)
    #endif
    public enum ValidationError: Error, Equatable, CustomDebugStringConvertible {
        /// Retained for backward compatibility. `text` and `images` are both
        /// optional now, so an empty payload no longer throws — this remains
        /// only as a defensive guard and is not raised for an empty payload.
        case contentEmpty

        /// `text` was shorter than the minimum length the editor
        /// requires at publish time. That minimum is one character
        /// (`Validators.Post.minTextLength`) and an empty `text` is
        /// normalized to `nil`, so this is no longer thrown; it is kept so
        /// existing `switch` statements stay exhaustive.
        case textTooShort(min: Int)

        /// `text` was longer than the maximum length the editor allows.
        case textTooLong(max: Int)

        /// The provided image bytes could not be decoded into a
        /// `UIImage`.
        case imageInvalid

        /// The image's longest side / shortest side ratio exceeded the
        /// allowed maximum.
        case imageRatioTooLarge(maxRatio: String)

        /// The image's shortest side was below the allowed minimum.
        case imageTooSmall(min: CGFloat)

        /// The CTA's `label` was empty / whitespace-only.
        case ctaLabelEmpty

        /// The CTA's `url.absoluteString` was empty.
        case ctaUrlEmpty

        public var debugDescription: String {
            switch self {
            case .contentEmpty:
                return "OctopusPrefilledPost.ValidationError.contentEmpty: " +
                    "at least one of `text` or `images` must be provided."
            case let .textTooShort(min):
                return "OctopusPrefilledPost.ValidationError.textTooShort: " +
                    "prefilled text is shorter than \(min) characters."
            case let .textTooLong(max):
                return "OctopusPrefilledPost.ValidationError.textTooLong: " +
                    "prefilled text exceeds \(max) characters."
            case .imageInvalid:
                return "OctopusPrefilledPost.ValidationError.imageInvalid: " +
                    "the provided image bytes could not be decoded."
            case let .imageRatioTooLarge(ratio):
                return "OctopusPrefilledPost.ValidationError.imageRatioTooLarge: " +
                    "image ratio exceeds \(ratio)."
            case let .imageTooSmall(min):
                return "OctopusPrefilledPost.ValidationError.imageTooSmall: " +
                    "image shortest side is below \(min)."
            case .ctaLabelEmpty:
                return "OctopusPrefilledPost.ValidationError.ctaLabelEmpty: " +
                    "CTA `label` must not be empty."
            case .ctaUrlEmpty:
                return "OctopusPrefilledPost.ValidationError.ctaUrlEmpty: " +
                    "CTA `url.absoluteString` must not be empty."
            }
        }
    }
}

// MARK: - Deprecated
extension OctopusPrefilledPost {
    /// The first of ``images``, or `nil` when there is none.
    @available(*, deprecated, message: "Use images.")
    public var image: Data? { images.first }

    /// ``bridgeShareTokenProvider`` with the non-optional result it had before it could return `nil`:
    /// when the provider returns `nil`, this closure throws.
    @available(*, deprecated, message: "Use bridgeShareTokenProvider, which returns nil when the post is not signed.")
    public var sign: (@Sendable (_ bridgeFingerprint: String) async throws -> String)? {
        guard let provider = bridgeShareTokenProvider else { return nil }
        return { @Sendable bridgeFingerprint async throws -> String in
            guard let token = try await provider(bridgeFingerprint) else { throw NoTokenError() }
            return token
        }
    }

    /// Thrown by the deprecated ``sign`` when ``bridgeShareTokenProvider`` returned `nil`.
    private struct NoTokenError: Error, CustomDebugStringConvertible {
        var debugDescription: String {
            "OctopusPrefilledPost.sign: bridgeShareTokenProvider returned nil, there is no token to return."
        }
    }

    /// Construct a prefilled-post payload carrying at most one image.
    ///
    /// - Parameters:
    ///   - text: Initial text shown in the editor. Optional — `nil` and
    ///     `""` are equivalent (no prefilled text).
    ///   - image: Initial image bytes shown in the editor. Optional —
    ///     `nil` and empty `Data` are equivalent.
    ///   - topicId: Identifier of the group to preselect.
    ///   - cta: Optional call-to-action attached to the published post.
    ///   - sign: Optional closure signing the content fingerprint, see ``bridgeShareTokenProvider``.
    /// - Throws: `OctopusPrefilledPost.ValidationError` if the (provided)
    ///   text length is out of bounds or the image cannot be decoded or
    ///   violates size/ratio constraints.
    /// - Note: Every parameter keeps its default, so existing calls compile unchanged. The overload
    ///   is disfavored: a call that does not pass `image:` resolves to
    ///   `init(text:images:topicId:cta:sign:)` instead, without a deprecation warning.
    @available(*, deprecated, message: "Use init(text:images:topicId:cta:sign:).")
    @_disfavoredOverload
    public init(text: String? = nil,
                image: Data? = nil,
                topicId: String? = nil,
                cta: CTA? = nil,
                sign: (@Sendable (_ bridgeFingerprint: String) async throws -> String?)? = nil) throws {
        try self.init(text: text,
                      images: image.map { [$0] } ?? [],
                      topicId: topicId,
                      cta: cta,
                      sign: sign)
    }
}
