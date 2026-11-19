//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Rules of the VoiceOver summary of a published post.
///
/// The media picks the sentence ("… and attached an image"). A poll, alone or next to a media, adds its
/// options to the text that is read. Images with neither text nor poll have their own sentence
/// ("… shared an image"). From two images on, the sentence tells how many there are.
enum PostSummaryAccessibility {
    enum Template: Equatable {
        case textOnly
        case textAndImage
        case textAndImages(count: Int)
        case textAndVideo
        case imageOnly
        case imagesOnly(count: Int)
    }

    /// - Parameter hasText: whether the post has text. A post may carry an image without text.
    static func template(for attachments: PostAttachmentsViewData, hasText: Bool) -> Template {
        switch attachments.media {
        case let .images(images):
            let hasTextToRead = hasText || attachments.poll != nil
            guard images.count > 1 else { return hasTextToRead ? .textAndImage : .imageOnly }
            return hasTextToRead ? .textAndImages(count: images.count) : .imagesOnly(count: images.count)
        case .video: return .textAndVideo
        case .none: return .textOnly
        }
    }

    /// - Parameter pollOptionsToRead: the poll options already formatted for VoiceOver, `nil` without poll.
    static func textToRead(_ text: String, pollOptionsToRead: String?) -> String {
        guard let pollOptionsToRead else { return text }
        guard !text.isEmpty else { return pollOptionsToRead }
        return "\(text), \(pollOptionsToRead)"
    }
}
