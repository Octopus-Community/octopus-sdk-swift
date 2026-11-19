//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// An Octopus Post that is linked to a client object (article, product...).
public struct ClientPost: Sendable {
    /// The attachment of a post
    #if hasAttribute(nonexhaustive)
    @nonexhaustive(warn)
    #endif
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
    /// The medias of the post, in display order. Each one can be a local image as Data or a distant image as URL.
    /// A post accepts up to 10 medias: more is refused by `fetchOrCreateClientObjectRelatedPost(content:tokenProvider:)`
    /// with a `ClientPostError.validation` on the `file` field. The deprecated calls without a token provider accept a
    /// single media and refuse more the same way.
    public let medias: [Attachment]

    /// The first of ``medias``, or `nil` when there is none.
    @available(*, deprecated, message: "Use medias.")
    public var attachment: Attachment? { medias.first }

    /// The text that will be displayed in a button to display your object. When the button containing this text will
    /// be tapped, the `displayClientObject` callback will be called with your object id.
    /// When the text is given per language (see ``viewClientObjectButton``), this is the label of the default
    /// language.
    /// If nil, the button won't be displayed.
    public let viewClientObjectButtonText: String?
    /// The text that will be displayed in a button to display your object, either translated automatically or given
    /// per language. When the button containing this text will be tapped, the `displayClientObject` callback will
    /// be called with your object id.
    /// If nil, the button won't be displayed.
    public let viewClientObjectButton: OctopusLocalizedText?
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
    ///   - medias: the medias of the post, in display order, up to 10. Each one can be a local image as Data or a
    ///             distant image as URL. Default is an empty list.
    ///   - viewClientObjectButton: the text that will be displayed in a button to display your object, either
    ///                             translated automatically (`.autoTranslated("See the recipe")`) or given per
    ///                             language (`try .perLanguage([...], defaultLanguage:)`).
    ///                             When the button containing this text will be tapped, the `displayClientObject`
    ///                             callback will be called with your object id.
    ///                             We recommand between 4 and 28 characters for each label: a longer one is
    ///                             displayed on one line, truncated.
    ///                             The labels are taken when the post is created: they are ignored when a post
    ///                             already exists for `clientObjectId`.
    ///                             If nil, the button won't be displayed.
    public init(clientObjectId: String,
                groupId: String? = nil,
                text: String,
                catchPhrase: String? = nil,
                medias: [Attachment] = [],
                viewClientObjectButton: OctopusLocalizedText?) {
        self.clientObjectId = clientObjectId
        self.groupId = groupId
        self.text = text
        self.catchPhrase = catchPhrase
        self.medias = medias
        self.viewClientObjectButton = viewClientObjectButton
        self.viewClientObjectButtonText = viewClientObjectButton?.defaultText
        self.signature = nil
    }

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
    ///   - medias: the medias of the post, in display order, up to 10. Each one can be a local image as Data or a
    ///             distant image as URL. Default is an empty list.
    ///   - viewClientObjectButtonText: the text that will be displayed in a button to display your object.
    ///                                 When the button containing this text will be tapped, the `displayClientObject`
    ///                                 callback will be called with your object id.
    ///                                 **Must be below 28 characters**. We recommand between 4 and 28 characters.
    ///                                 The text is translated automatically, as `.autoTranslated(_:)` does.
    @available(*, deprecated, message: "Use init(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:) with .autoTranslated(_:) to keep the automatic translation, or .perLanguage(_:defaultLanguage:) to give the text per language.")
    public init(clientObjectId: String,
                groupId: String? = nil,
                text: String,
                catchPhrase: String? = nil,
                medias: [Attachment] = [],
                viewClientObjectButtonText: String?) {
        self.clientObjectId = clientObjectId
        self.groupId = groupId
        self.text = text
        self.catchPhrase = catchPhrase
        self.medias = medias
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.viewClientObjectButton = viewClientObjectButtonText.map { .autoTranslated($0) }
        self.signature = nil
    }

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
    ///                 It becomes the only element of ``medias``.
    ///   - viewClientObjectButtonText: the text that will be displayed in a button to display your object.
    ///                                 When the button containing this text will be tapped, the `displayClientObject`
    ///                                 callback will be called with your object id.
    ///                                 **Must be below 28 characters**. We recommand between 4 and 28 characters.
    @available(*, deprecated, message: "Use init(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:).")
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
        self.medias = attachment.map { [$0] } ?? []
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.viewClientObjectButton = viewClientObjectButtonText.map { .autoTranslated($0) }
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
    ///                 It becomes the only element of ``medias``.
    ///   - viewClientObjectButtonText: the text that will be displayed in a button to display your object.
    ///                                 When the button containing this text will be tapped, the `displayClientObject`
    ///                                 callback will be called with your object id.
    ///                                 **Must be below 28 characters**. We recommand between 4 and 28 characters.
    ///   - signature: a token signed to ensure the request comes from an authorized requester. Required if your
    ///                community is configured to ensure signature is passed.
    @available(*, deprecated, message: "The signature param is deprecated. For more security, the signature will be asked in a callback if needed and it will be signed according to the post's content. Use init(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:).")
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
        self.medias = attachment.map { [$0] } ?? []
        self.viewClientObjectButtonText = viewClientObjectButtonText
        self.viewClientObjectButton = viewClientObjectButtonText.map { .autoTranslated($0) }
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
            medias: medias.map(\.coreValue),
            viewClientObjectButtonText: viewClientObjectButtonText,
            viewClientObjectButtonLabels: viewClientObjectButton?.corePerLanguageLabels,
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

extension ClientPost {
    /// Refuses a post that carries more medias than a post can hold, before any network call.
    ///
    /// The back refuses it too, but a precise error raised here saves the round trip. A dedicated
    /// `ErrorKind` is not added: an integrator's exhaustive `switch` must keep compiling, so the
    /// diagnosis travels in the message.
    static func validateMediaCount(_ post: ClientPost) throws(ClientPostError) {
        let max = Validators.Post.maxImageCount
        guard post.medias.count <= max else {
            throw .validation([
                ClientPostError.ValidationError(
                    errorKind: .unknown,
                    field: .file,
                    message: "A client post accepts at most \(max) medias, \(post.medias.count) were provided.")
            ])
        }
    }

    /// Refuses a post that carries more than one media, before any network call, for the deprecated calls that take
    /// no token provider.
    ///
    /// Those calls create the post in a single request that carries its images, and the back takes only one image
    /// there. Several medias go through `fetchOrCreateClientObjectRelatedPost(content:tokenProvider:)`, which uploads
    /// the local images first.
    static func validateMediaCountWithoutTokenProvider(_ post: ClientPost) throws(ClientPostError) {
        guard post.medias.count <= 1 else {
            throw .validation([
                ClientPostError.ValidationError(
                    errorKind: .unknown,
                    field: .file,
                    message: "Without a token provider, a client post accepts a single media, \(post.medias.count) " +
                        "were provided. Use fetchOrCreateClientObjectRelatedPost(content:tokenProvider:) to send " +
                        "several.")
            ])
        }
    }
}
