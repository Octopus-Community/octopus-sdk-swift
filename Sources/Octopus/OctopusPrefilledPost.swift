//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import OctopusCore

/// A payload carrying content that prefills the Octopus post editor when
/// the host opens the SDK via `OctopusInitialScreen.createPost(...)`.
///
/// The host supplies any combination of text, image, topic and CTA; the
/// user can freely edit text, image and topic in the editor before
/// publishing. The CTA travels invisibly through the editor and is
/// attached to the published post.
///
/// The initializer reuses the same validation rules the editor enforces
/// at publish time (text length, image size/ratio), so integration bugs
/// surface during client-app QA instead of after the editor opens.
public struct OctopusPrefilledPost: Sendable {
    /// The text the editor opens with. Optional, but at least one of
    /// `text` or `image` must be non-nil.
    public let text: String?

    /// Local image bytes (e.g. `UIImage(...).jpegData(...)`). The SDK
    /// does not fetch remote URLs — the host materializes the bytes
    /// before constructing this payload.
    public let image: Data?

    /// Identifier of the group the post should land in. If `nil` or
    /// inaccessible, the user picks a group in the editor before
    /// publishing.
    public let topicId: String?

    /// Optional call-to-action button attached to the published post.
    /// Not displayed in the editor — the user cannot see, edit, or
    /// remove the CTA.
    public let cta: CTA?

    /// Construct a prefilled-post payload.
    ///
    /// - Parameters:
    ///   - text: Initial text shown in the editor. `nil` and `""` are
    ///     equivalent (no prefilled text). At least one of `text` /
    ///     `image` must be provided.
    ///   - image: Initial image bytes shown in the editor. `nil` and
    ///     empty `Data` are equivalent.
    ///   - topicId: Identifier of the group to preselect.
    ///   - cta: Optional call-to-action attached to the published post.
    /// - Throws: `OctopusPrefilledPost.ValidationError` if the payload
    ///   is empty, the text length is out of bounds, the image cannot
    ///   be decoded or violates size/ratio constraints, or the CTA is
    ///   malformed.
    public init(text: String? = nil,
                image: Data? = nil,
                topicId: String? = nil,
                cta: CTA? = nil) throws {
        let normalizedText: String? = (text?.isEmpty == true) ? nil : text
        let normalizedImage: Data? = (image?.isEmpty == true) ? nil : image

        guard normalizedText != nil || normalizedImage != nil else {
            throw ValidationError.contentEmpty
        }

        // Match the editor's publish-time validation: pass the image
        // attachment so the too-short rule fires consistently
        // (Validators.Post only waives too-short for .poll).
        let attachmentForValidation: WritablePost.Attachment?
        if let normalizedImage {
            attachmentForValidation = .image(normalizedImage)
        } else {
            attachmentForValidation = nil
        }

        if let normalizedText {
            switch Validators.Post.validate(
                text: normalizedText,
                attachment: attachmentForValidation,
                ignoreTooShort: false
            ) {
            case .success: break
            case .failure(.empty): throw ValidationError.contentEmpty // defensive; normalization caught it
            case .failure(.tooShort):
                throw ValidationError.textTooShort(min: Validators.Post.minTextLength)
            case .failure(.tooLong):
                throw ValidationError.textTooLong(max: Validators.Post.maxTextLength)
            }
        }

        if let normalizedImage {
            guard let uiImage = UIImage(data: normalizedImage) else {
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
        self.image = normalizedImage
        self.topicId = topicId
        self.cta = cta
    }

    /// A call-to-action button attached to the published post.
    public struct CTA: Sendable, Equatable {
        /// URL opened when the user taps the button. May be a custom
        /// scheme handled by the host's deeplink registration, an
        /// `https://` URL, or any other URL the OS knows how to route.
        public let url: URL

        /// Text shown on the button.
        public let label: String

        /// Construct a CTA.
        ///
        /// - Parameters:
        ///   - url: URL opened when the user taps the button.
        ///   - label: Text shown on the button.
        /// - Throws: `.ctaLabelEmpty` if `label` is empty after
        ///   trimming whitespace; `.ctaUrlEmpty` if `url.absoluteString`
        ///   is empty.
        public init(url: URL, label: String) throws {
            guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.ctaLabelEmpty
            }
            guard !url.absoluteString.isEmpty else {
                throw ValidationError.ctaUrlEmpty
            }
            self.url = url
            self.label = label
        }
    }

    /// Validation failures surfaced by `OctopusPrefilledPost.init` and
    /// `OctopusPrefilledPost.CTA.init`.
    public enum ValidationError: Error, Equatable, CustomDebugStringConvertible {
        /// Both `text` and `image` were nil (after normalizing `""` and
        /// empty `Data` to nil). At least one is required.
        case contentEmpty

        /// `text` was shorter than the minimum length the editor
        /// requires at publish time.
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
                    "at least one of `text` or `image` must be provided."
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
