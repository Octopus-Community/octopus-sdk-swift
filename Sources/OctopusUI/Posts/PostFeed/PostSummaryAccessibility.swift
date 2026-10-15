//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Rules of the VoiceOver summary of a published post.
///
/// The media picks the sentence ("… and attached an image"). A poll, alone or next to a media, adds its
/// options to the text that is read. An image with neither text nor poll has its own sentence
/// ("… shared an image").
enum PostSummaryAccessibility {
    enum Template: Equatable {
        case textOnly
        case textAndImage
        case textAndVideo
        case imageOnly
    }

    /// - Parameter hasText: whether the post has text. A post may carry an image without text.
    static func template(for attachments: PostAttachmentsViewData, hasText: Bool) -> Template {
        switch attachments.media {
        case .image: hasText || attachments.poll != nil ? .textAndImage : .imageOnly
        case .video: .textAndVideo
        case .none: .textOnly
        }
    }

    /// - Parameter pollOptionsToRead: the poll options already formatted for VoiceOver, `nil` without poll.
    static func textToRead(_ text: String, pollOptionsToRead: String?) -> String {
        guard let pollOptionsToRead else { return text }
        guard !text.isEmpty else { return pollOptionsToRead }
        return "\(text), \(pollOptionsToRead)"
    }
}
