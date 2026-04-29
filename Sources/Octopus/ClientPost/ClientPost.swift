//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// An Octopus Post that is linked to a client object (article, product...).
public struct ClientPost: Sendable {
    /// The attachment of a post
    public enum Attachment: Sendable {
        /// Local image. The data should have been get from the API `jpegData` or `pngData` of UIImage or
        /// UIGraphicsImageRenderer.
        case localImage(Data)
        /// Web hosted image. The url must point to the image file directly.
        case distantImage(URL)
    }
    /// An id that uniquely identifies the object linked to this post. It will be used to retrieve the post if it
    /// already exists and in the `displayClientObject` callback.
    public let clientObjectId: String
    /// The group id to save your post to. If nil, a default group that you should configure with our backend team will
    /// be used.
    public let groupId: String?

    /// The topic id to save your post to.
    @available(*, deprecated, renamed: "groupId")
    public var topicId: String? { groupId }
    /// The text of the post. Length must be between 10 and 5000 characters.
    public let text: String
    /// The catch phrase. You can use something like "What do you think about this?". It will be displayed below the
    /// text, in bold. Must be below 84 characters. We recommand between 6 and 38 characters.
    /// If nil, it won't be displayed.
    public let catchPhrase: String?
    /// The attachment of the post. It can be a local image as Data or a distant image as URL.
    public let attachment: Attachment?
    /// The text that will be displayed in a button to display your object. When the button containing this text will
    /// be tapped, the `displayClientObject` callback will be called with your object id.
    /// Must be below 28 characters. We recommand between 4 and 28 characters.
    /// If nil, the button won't be displayed.
    public let viewClientObjectButtonText: String?
    /// A token signed to ensure the request comes from an authorized requester. Deprecated and not used anymore.
    /// For more security, the signature will be asked in a callback if needed and it will be signed according to the
    /// post's content.
    public let signature: String?

    /// Constructor of a `ClientObjectRelatedPost`.
    /// - Parameters:
    ///   - clientObjectId: an id that uniquely identifies the object linked to this post. It will be used to retrieve
    ///                     the post if it already exists and in the `displayClientObject` callback.
    ///   - groupId: the group id to save your post to. If nil, a default group that you should configure with our
    ///              backend team will be used.
    ///              Default is nil.
    ///   - text: the text of the post. Length must be between 10 and 5000 characters.
    ///   - catchPhrase: the catch phrase. You can use something like "What do you think about this?". It will be
    ///                  displayed below the text, in bold.
    ///                  **Must be below 84 characters**. We recommand between 6 and 38 characters.
    ///                  If nil, it won't be displayed. Default is nil.
    ///   - attachment: the attachment of the post. It can be a local image as Data or a distant image as URL.
    ///   - viewClientObjectButtonText: the text that will be displayed in a button to display your object.
    ///                                 When the button containing this text will be tapped, the `displayClientObject`
    ///                                 callback will be called with your object id.
    ///                                 **Must be below 28 characters**. We recommand between 4 and 28 characters.
    public init(clientObjectId: String,
                groupId: String? = nil,
                text: String,
                catchPhrase: String? = nil,
                attachment: Attachment?,
                viewClientObjectButtonText: String?) {
        self.clientObjectId = clientObjectId
        self.groupId = groupId
        self.text = text
        self.catchPhrase = catchPhrase
        self.attachment = attachment
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.signature = nil
    }

    /// Constructor of a `ClientObjectRelatedPost`.
    /// - Parameters:
    ///   - clientObjectId: an id that uniquely identifies the object linked to this post. It will be used to retrieve
    ///                     the post if it already exists and in the `displayClientObject` callback.
    ///   - topicId: the topic id to save your post to. If nil, a default topic that you should configure with our
    ///              backend team will be used.
    ///              Default is nil.
    ///   - text: the text of the post. Length must be between 10 and 5000 characters.
    ///   - catchPhrase: the catch phrase. You can use something like "What do you think about this?". It will be
    ///                  displayed below the text, in bold.
    ///                  **Must be below 84 characters**. We recommand between 6 and 38 characters.
    ///                  If nil, it won't be displayed. Default is nil.
    ///   - attachment: the attachment of the post. It can be a local image as Data or a distant image as URL.
    ///   - viewClientObjectButtonText: the text that will be displayed in a button to display your object.
    ///                                 When the button containing this text will be tapped, the `displayClientObject`
    ///                                 callback will be called with your object id.
    ///                                 **Must be below 28 characters**. We recommand between 4 and 28 characters.
    ///   - signature: a token signed to ensure the request comes from an authorized requester. Required if your
    ///                community is configured to ensure signature is passed.
    @available(*, deprecated, message: "The signature param is deprecated. For more security, the signature will be asked in a callback if needed and it will be signed according to the post's content.")
    public init(clientObjectId: String,
                topicId: String? = nil,
                text: String,
                catchPhrase: String? = nil,
                attachment: Attachment?,
                viewClientObjectButtonText: String?,
                signature: String?) {
        self.clientObjectId = clientObjectId
        self.groupId = topicId
        self.text = text
        self.catchPhrase = catchPhrase
        self.attachment = attachment
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.signature = signature
    }
}

extension ClientPost {
    var coreValue: OctopusCore.ClientPost {
        .init(
            clientObjectId: clientObjectId,
            groupId: groupId,
            text: text,
            catchPhrase: catchPhrase,
            attachment: attachment?.coreValue,
            viewClientObjectButtonText: viewClientObjectButtonText,
            signature: signature)
    }
}

extension ClientPost.Attachment {
    var coreValue: OctopusCore.ClientPost.Attachment {
        switch self {
        case let .localImage(imgData):
                .localImage(imgData)
        case let .distantImage(url):
                .distantImage(url)
        }
    }
}
