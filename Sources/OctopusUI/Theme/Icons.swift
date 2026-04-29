//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import UIKit

extension OctopusTheme.Assets {
    public struct Icons: Sendable {
        /// Group of icons used for groups
        public struct Groups: Sendable {
            /// Displayed to open the group list
            public let openList: UIImage
            /// Displayed in the group list when the group is selected (checkmark)
            public let selected: UIImage
        }

        /// Group of icons used for content (Posts, Comments, Replies...)
        public struct Content: Sendable {
            /// Group of icons used for Posts
            public struct Post: Sendable {
                /// Group of icons used for post creation
                public struct Creation: Sendable {
                    /// Displayed on the main feed, to open the post creation screen
                    public let open: UIImage
                    /// Displayed near the topic to open the topic selection screen (arrow down)
                    public let topicSelection: UIImage
                    /// Displayed to add a picture to the post
                    /// Default value is `defaultAddPicture` set in the Content init.
                    public fileprivate(set) var addPicture: UIImage
                    /// Displayed to delete a picture on a post during its creation
                    /// Default value is `defaultDeletePicture` set in the Content init.
                    public fileprivate(set) var deletePicture: UIImage
                    /// Displayed to add a poll to the post
                    public let addPoll: UIImage
                    /// Displayed to add a new option to the poll (plus sign)
                    public let addPollOption: UIImage
                    /// Displayed to delete a poll on a post during its creation
                    public let deletePoll: UIImage
                    /// Displayed to delete a poll option on a post during its creation
                    public let deletePollOption: UIImage

                    fileprivate let addPictureIsDefault: Bool
                    fileprivate let deletePictureIsDefault: Bool
                }

                /// Group of icons used during Post creation
                public fileprivate(set) var creation: Creation
                /// Image displayed when the post feed of a given group is empty
                public let emptyFeedInGroups: UIImage
                /// Image displayed in the current user profile when the current user has not created any post
                public let emptyFeedInCurrentUserProfile: UIImage
                /// Image displayed in a user profile when they have not created any post
                public let emptyFeedInOtherUserProfile: UIImage
                /// Displayed when a post is not available anymore (moderated, deleted...)
                /// Default value is `defaultNotAvailable` set in the Content init.
                public fileprivate(set) var notAvailable: UIImage
                /// Displayed to indicate the number of comments on a post
                public let commentCount: UIImage
                /// Displayed to indicate the number of views
                public let viewCount: UIImage
                /// Displayed to open the reaction picker
                public let moreReactions: UIImage
                /// Displayed when the current user has not reacted on this post
                /// Default value is `defaultLikeNotSelected` set in the Content init.
                public fileprivate(set) var likeNotSelected: UIImage
                /// Displayed on the moderated tag of a moderated post
                public let moderated: UIImage

                fileprivate let notAvailableIsDefault: Bool
                fileprivate let likeNotSelectedIsDefault: Bool
            }

            /// Group of icons used for Comments
            public struct Comment: Sendable {
                /// Group of icons used during Comment creation
                public struct Creation: Sendable {
                    /// Displayed to open the comment creation
                    public fileprivate(set) var open: UIImage
                    /// Displayed to send the new comment
                    public fileprivate(set) var create: UIImage
                    /// Displayed to add a picture to the comment.
                    /// Default value is `defaultAddPicture` set in the Content init.
                    public fileprivate(set) var addPicture: UIImage
                    /// Displayed to delete a picture on a comment during its creation
                    /// Default value is `defaultDeletePicture` set in the Content init.
                    public fileprivate(set) var deletePicture: UIImage

                    fileprivate let openIsDefault: Bool
                    fileprivate let createIsDefault: Bool
                    fileprivate let addPictureIsDefault: Bool
                    fileprivate let deletePictureIsDefault: Bool
                }

                /// Group of icons used during Comment creation
                public fileprivate(set) var creation: Creation
                /// Image displayed when the post has no comments
                public let emptyFeed: UIImage
                /// Displayed when a post is not available anymore (moderated, deleted...)
                /// Default value is `defaultNotAvailable` set in the Content init.
                public fileprivate(set) var notAvailable: UIImage
                /// Displayed to see the replies (arrow right)
                public let seeReply: UIImage
                /// Displayed when the current user has not reacted on this comment
                /// Default value is `defaultLikeNotSelected` set in the Content init.
                public fileprivate(set) var likeNotSelected: UIImage

                fileprivate let notAvailableIsDefault: Bool
                fileprivate let likeNotSelectedIsDefault: Bool
            }

            /// Group of icons used for Replies
            public struct Reply: Sendable {
                /// Group of icons used during Reply creation
                public struct Creation: Sendable {
                    /// Displayed to open the reply creation
                    public fileprivate(set) var open: UIImage
                    /// Displayed to send the new reply
                    public fileprivate(set) var create: UIImage
                    /// Displayed to add a picture to the reply.
                    /// Default value is `defaultAddPicture` set in the Content init.
                    public fileprivate(set) var addPicture: UIImage
                    /// Displayed to delete a picture on a reply during its creation
                    /// Default value is `defaultDeletePicture` set in the Content init.
                    public fileprivate(set) var deletePicture: UIImage

                    fileprivate let openIsDefault: Bool
                    fileprivate let createIsDefault: Bool
                    fileprivate let addPictureIsDefault: Bool
                    fileprivate let deletePictureIsDefault: Bool
                }

                /// Group of icons used during Reply creation
                public fileprivate(set) var creation: Creation
                /// Displayed when the current user has not reacted on this reply
                /// Default value is `defaultLikeNotSelected` set in the Content init.
                public fileprivate(set) var likeNotSelected: UIImage

                fileprivate let likeNotSelectedIsDefault: Bool
            }

            /// Group of icons used for videos
            public struct Video: Sendable {
                /// Displayed when the video is muted
                public let muted: UIImage
                /// Displayed when the video is not muted
                public let notMuted: UIImage
                /// Displayed to pause the video
                public let pause: UIImage
                /// Displayed to play the video
                public let play: UIImage
                /// Displayed to replay the video
                public let replay: UIImage
            }

            /// Group of icons used for polls
            public struct Poll: Sendable {
                /// Displayed on a selected option of a poll
                public let selectedOption: UIImage
            }

            /// Group of images used for reactions (heart, joy, surprise, clap, cry, rage).
            /// Unlike other SDK icons, reaction images are rendered with their original colors
            /// (not tinted as templates).
            public struct Reaction: Sendable {
                /// Image for the heart reaction
                public let heart: UIImage
                /// Image for the joy reaction
                public let joy: UIImage
                /// Image for the mouth-open (surprise) reaction
                public let mouthOpen: UIImage
                /// Image for the clap reaction
                public let clap: UIImage
                /// Image for the cry reaction
                public let cry: UIImage
                /// Image for the rage reaction
                public let rage: UIImage
            }

            /// Group of icons used for posts
            public fileprivate(set) var post: Post
            /// Group of icons used for comments
            public fileprivate(set) var comment: Comment
            /// Group of icons used for replies
            public fileprivate(set) var reply: Reply
            /// Group of icons used for video
            public let video: Video
            /// Group of icons used for polls
            public let poll: Poll
            /// Group of images used for reactions
            public let reaction: Reaction
            /// Displayed to delete a content
            public let delete: UIImage
            /// Displayed to report a content
            /// Default value is `defaultReport` set in the Icon init.
            public fileprivate(set) var report: UIImage

            fileprivate let reportIsDefault: Bool
        }

        /// On/off components icons
        public struct OnOff: Sendable {
            /// Displayed when the component is on
            public let on: UIImage
            /// Displayed when the component is off
            public let off: UIImage

            /// Set the On and Off icons of a component that has two states
            /// - Parameters:
            ///   - on: the image displayed when the component is on
            ///   - off: the image displayed when the component is off
            public init(on: UIImage, off: UIImage) {
                self.on = on.prepareForSdkUsage()
                self.off = off.prepareForSdkUsage()
            }
        }

        /// Group of icons used for gamification
        public struct Gamification: Sendable {
            /// The badge of a user. It will be tinted with the color of the level
            public let badge: UIImage
            /// Displayed to open the rules
            public let info: UIImage
            /// Displayed on the rules
            public let rulesHeader: UIImage
        }

        /// Group of icons used for the settings
        public struct Settings: Sendable {
            /// Displayed to open the account page (only on Octopus auth mode)
            public let account: UIImage
            /// Displayed to open the help page
            public let help: UIImage
            /// Displayed to open the info page
            public let info: UIImage
            /// Displayed to logout the current user (only on Octopus auth mode)
            public let logout: UIImage
            /// Displayed to delete the current user (only on Octopus auth mode)
            public let deleteAccountWarning: UIImage
        }

        /// Group of icons used for the profile
        public struct Profile: Sendable {
            /// Displayed in the current user profile, on a default avatar, for the user to add a picture
            public let addPicture: UIImage
            /// Displayed in the profile edit screen, on the user's avatar to change the picture
            public let editPicture: UIImage
            /// Displayed in the current user profile, when the user's bio is empty
            public let addBio: UIImage
            /// Displayed in the current user profile, when the user has no internal notification
            public let emptyNotifications: UIImage
            /// Displayed to report a content
            /// Default value is `defaultReport` set in the Icon init.
            public fileprivate(set) var report: UIImage
            /// Displayed as avatar when the user is not connected (error state)
            public let notConnected: UIImage
            /// Displayed to block a user
            public let blockUser: UIImage

            fileprivate let reportIsDefault: Bool
        }

        /// Group of icons used commonly
        public struct Common: Sendable {
            /// Radio button icons
            public let radio: OnOff
            /// Checkbox button icons
            public let checkbox: OnOff
            /// Toggle button icons.
            public let toggle: OnOff
            /// Close button
            public let close: UIImage
            /// More actions button
            public let moreActions: UIImage
            /// List cell navigation indicator (arrow  right)
            public let listCellNavIndicator: UIImage
        }

        /// Group of icons used for groups
        public let groups: Groups
        /// Group of icons used for content (posts, comments, replies...)
        public fileprivate(set) var content: Content
        /// Group of icons used for profile
        public fileprivate(set) var profile: Profile
        /// Group of icons used for gamification
        public let gamification: Gamification
        /// Group of icons used for the settings
        public let settings: Settings
        /// Common icons
        public let common: Common
    }
}

private extension UIImage {
    func prepareForSdkUsage() -> UIImage {
        withRenderingMode(.alwaysTemplate)
    }
}

extension OctopusTheme.Assets.Icons.Groups {
    /// Constructor of Groups related icons
    /// - Parameters:
    ///   - openList: Displayed to open the group list
    ///   - selected: Displayed in the group list when the group is selected (checkmark)
    public init(
        openList: UIImage? = nil,
        selected: UIImage? = nil
    ) {
        self.openList = openList?.prepareForSdkUsage() ?? .Gen.search
        self.selected = selected?.prepareForSdkUsage() ?? .Gen.check
    }
}

extension OctopusTheme.Assets.Icons.Content.Post.Creation {
    /// Constructor of Post creation related icons
    /// - Parameters:
    ///   - open: Displayed on the main feed, to open the post creation screen
    ///   - topicSelection: Displayed near the topic to open the topic selection screen (arrow down)
    ///   - addPicture: Displayed to add a picture to the post.
    ///                 Default value is `defaultAddPicture` set in the Content init.
    ///   - deletePicture: Displayed to delete a picture on a post during its creation
    ///                    Default value is `defaultDeletePicture` set in the Content init.
    ///   - addPoll: Displayed to add a poll to the post
    ///   - addPollOption: Displayed to add a new option to the poll (plus sign)
    ///   - deletePoll: Displayed to delete a poll on a post during its creation
    ///   - deletePollOption: Displayed to delete a poll option on a post during its creation
    public init(
        open: UIImage? = nil,
        topicSelection: UIImage? = nil,
        addPicture: UIImage? = nil,
        deletePicture: UIImage? = nil,
        addPoll: UIImage? = nil,
        addPollOption: UIImage? = nil,
        deletePoll: UIImage? = nil,
        deletePollOption: UIImage? = nil
    ) {
        self.open = open?.prepareForSdkUsage() ?? .Gen.createPost
        self.topicSelection = topicSelection?.prepareForSdkUsage() ?? .Gen.down
        self.addPicture = addPicture?.prepareForSdkUsage() ?? .Gen.addMedia
        self.deletePicture = deletePicture?.prepareForSdkUsage() ?? .Gen.closeLight
        self.addPoll = addPoll?.prepareForSdkUsage() ?? .Gen.poll
        self.addPollOption = addPollOption?.prepareForSdkUsage() ?? .Gen.add
        self.deletePoll = deletePoll?.prepareForSdkUsage() ?? .Gen.trash
        self.deletePollOption = deletePollOption?.prepareForSdkUsage() ?? .Gen.closeLight

        self.addPictureIsDefault = addPicture == nil
        self.deletePictureIsDefault = deletePicture == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Post {
    /// Constructor of Post related icons
    /// - Parameters:
    ///   - creation: Group of icons used during Post creation
    ///   - emptyFeedInGroups: Image displayed when the post feed of a given group is empty
    ///   - emptyFeedInCurrentUserProfile: Image displayed in the current user profile when the current user has not
    ///                                    created any post
    ///   - emptyFeedInOtherUserProfile: Image displayed in a user profile when they have not created any post
    ///   - notAvailable: Displayed when a post is not available anymore (moderated, deleted...)
    ///                   Default value is `defaultNotAvailable` set in the Content init.
    ///   - commentCount: Displayed to indicate the number of comments on a post
    ///   - viewCount: Displayed to indicate the number of views
    ///   - moreReactions: Displayed to open the reaction picker
    ///   - likeNotSelected: Displayed when the current user has not reacted on this post
    ///                      Default value is `defaultLikeNotSelected` set in the Content init.
    ///   - moderated: Displayed on the moderated tag of a moderated post
    public init(
        creation: Creation = .init(),
        emptyFeedInGroups: UIImage? = nil,
        emptyFeedInCurrentUserProfile: UIImage? = nil,
        emptyFeedInOtherUserProfile: UIImage? = nil,
        notAvailable: UIImage? = nil,
        commentCount: UIImage? = nil,
        viewCount: UIImage? = nil,
        moreReactions: UIImage? = nil,
        likeNotSelected: UIImage? = nil,
        moderated: UIImage? = nil
    ) {
        self.creation = creation
        self.emptyFeedInGroups = emptyFeedInGroups?.prepareForSdkUsage() ?? .Gen.noPosts
        self.emptyFeedInCurrentUserProfile = emptyFeedInCurrentUserProfile?.prepareForSdkUsage() ?? .Gen.noCurrentUserPost
        self.emptyFeedInOtherUserProfile = emptyFeedInOtherUserProfile?.prepareForSdkUsage() ?? .Gen.noPosts
        self.notAvailable = notAvailable?.prepareForSdkUsage() ?? .Gen.contentNotAvailable
        self.commentCount = commentCount?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.comment
        self.viewCount = viewCount?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.view
        self.moreReactions = moreReactions?.prepareForSdkUsage() ?? .Gen.add
        self.likeNotSelected = likeNotSelected?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.like
        self.moderated = moderated?.prepareForSdkUsage() ?? .Gen.moderation

        self.notAvailableIsDefault = notAvailable == nil
        self.likeNotSelectedIsDefault = likeNotSelected == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Comment.Creation {
    /// Constructor of Comment creation related icons
    /// - Parameters:
    ///   - open: Displayed to open the comment creation
    ///   - create: Displayed to send the new comment
    ///   - addPicture: Displayed to add a picture to the comment.
    ///                 Default value is `defaultAddPicture` set in the Content init.
    ///   - deletePicture: Displayed to delete a picture on a comment during its creation
    ///                    Default value is `defaultDeletePicture` set in the Content init.
    public init(
        open: UIImage? = nil,
        create: UIImage? = nil,
        addPicture: UIImage? = nil,
        deletePicture: UIImage? = nil
    ) {
        self.open = open?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.comment
        self.create = create?.prepareForSdkUsage() ?? .Gen.send
        self.addPicture = addPicture?.prepareForSdkUsage() ?? .Gen.addMedia
        self.deletePicture = deletePicture?.prepareForSdkUsage() ?? .Gen.closeLight

        self.openIsDefault = open == nil
        self.createIsDefault = create == nil
        self.addPictureIsDefault = addPicture == nil
        self.deletePictureIsDefault = deletePicture == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Comment {
    /// Constructor of Comment related icons
    /// - Parameters:
    ///   - creation: Group of icons used during Comment creation
    ///   - emptyFeed: Image displayed when the post has no comments
    ///   - notAvailable: Displayed when a post is not available anymore (moderated, deleted...)
    ///                   Default value is `defaultNotAvailable` set in the Content init.
    ///   - seeReply: Displayed to see the replies (arrow right)
    ///   - likeNotSelected: Displayed when the current user has not reacted on this comment
    ///                      Default value is `defaultLikeNotSelected` set in the Content init.
    public init(
        creation: Creation = .init(),
        emptyFeed: UIImage? = nil,
        notAvailable: UIImage? = nil,
        seeReply: UIImage? = nil,
        likeNotSelected: UIImage? = nil
    ) {
        self.creation = creation
        self.emptyFeed = emptyFeed?.prepareForSdkUsage() ?? .Gen.contentNotAvailable
        self.notAvailable = notAvailable?.prepareForSdkUsage() ?? .Gen.contentNotAvailable
        self.seeReply = seeReply?.prepareForSdkUsage() ?? .Gen.arrowRight
        self.likeNotSelected = likeNotSelected?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.like

        self.notAvailableIsDefault = notAvailable == nil
        self.likeNotSelectedIsDefault = likeNotSelected == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Reply.Creation {
    /// Constructor of Reply creation related icons
    /// - Parameters:
    ///   - open: Displayed to open the reply creation
    ///   - create: Displayed to send the new reply
    ///   - addPicture: Displayed to add a picture to the reply.
    ///                 Default value is `defaultAddPicture` set in the Content init.
    ///   - deletePicture: Displayed to delete a picture on a reply during its creation
    ///                    Default value is `defaultDeletePicture` set in the Content init.
    public init(
        open: UIImage? = nil,
        create: UIImage? = nil,
        addPicture: UIImage? = nil,
        deletePicture: UIImage? = nil
    ) {
        self.open = open?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.comment
        self.create = create?.prepareForSdkUsage() ?? .Gen.send
        self.addPicture = addPicture?.prepareForSdkUsage() ?? .Gen.addMedia
        self.deletePicture = deletePicture?.prepareForSdkUsage() ?? .Gen.closeLight

        self.openIsDefault = open == nil
        self.createIsDefault = create == nil
        self.addPictureIsDefault = addPicture == nil
        self.deletePictureIsDefault = deletePicture == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Reply {
    /// Constructor of Reply related icons
    /// - Parameters:
    ///   - creation: Group of icons used during Reply creation
    ///   - likeNotSelected: Displayed when the current user has not reacted on this reply
    ///                      Default value is `defaultLikeNotSelected` set in the Content init.
    public init(
        creation: Creation = .init(),
        likeNotSelected: UIImage? = nil
    ) {
        self.creation = creation
        self.likeNotSelected = likeNotSelected?.prepareForSdkUsage() ?? .Gen.AggregatedInfo.like

        self.likeNotSelectedIsDefault = likeNotSelected == nil
    }
}

extension OctopusTheme.Assets.Icons.Content.Video {
    /// Constructor of video related icons
    /// - Parameters:
    ///   - muted: Displayed when the video is muted
    ///   - notMuted: Displayed when the video is not muted
    ///   - pause: Displayed to pause the video
    ///   - play: Displayed to play the video
    ///   - replay: Displayed to replay the video
    public init(
        muted: UIImage? = nil,
        notMuted: UIImage? = nil,
        pause: UIImage? = nil,
        play: UIImage? = nil,
        replay: UIImage? = nil
    ) {
        self.muted = muted?.prepareForSdkUsage() ?? .Gen.Video.muted
        self.notMuted = notMuted?.prepareForSdkUsage() ?? .Gen.Video.notMuted
        self.pause = pause?.prepareForSdkUsage() ?? .Gen.Video.pause
        self.play = play?.prepareForSdkUsage() ?? .Gen.Video.play
        self.replay = replay?.prepareForSdkUsage() ?? .Gen.Video.replay
    }
}

extension OctopusTheme.Assets.Icons.Content.Poll {
    /// Constructor of video related icons
    /// - Parameters:
    ///   - selectedOption: Displayed on a selected option of a poll
    public init(
        selectedOption: UIImage? = nil,
    ) {
        self.selectedOption = selectedOption?.prepareForSdkUsage() ?? .Gen.circledCheck
    }
}

extension OctopusTheme.Assets.Icons.Content.Reaction {
    /// Constructor of Reaction images.
    ///
    /// Reaction images are rendered with their original colors (not tinted).
    /// If you do not override an image, the default emoji-style asset from the SDK is used.
    ///
    /// - Parameters:
    ///   - heart: Image for the heart reaction
    ///   - joy: Image for the joy reaction
    ///   - mouthOpen: Image for the mouth-open (surprise) reaction
    ///   - clap: Image for the clap reaction
    ///   - cry: Image for the cry reaction
    ///   - rage: Image for the rage reaction
    public init(
        heart: UIImage? = nil,
        joy: UIImage? = nil,
        mouthOpen: UIImage? = nil,
        clap: UIImage? = nil,
        cry: UIImage? = nil,
        rage: UIImage? = nil
    ) {
        self.heart = heart ?? .Gen.Reaction.heart
        self.joy = joy ?? .Gen.Reaction.joy
        self.mouthOpen = mouthOpen ?? .Gen.Reaction.mouthOpen
        self.clap = clap ?? .Gen.Reaction.clap
        self.cry = cry ?? .Gen.Reaction.cry
        self.rage = rage ?? .Gen.Reaction.rage
    }
}

extension OctopusTheme.Assets.Icons.Content {
    /// Group of icons used for content (Posts, Comments, Replies...)
    /// - Parameters:
    ///   - post: Group of icons used for posts
    ///   - comment: Group of icons used for comments
    ///   - reply: Group of icons used for replies
    ///   - video: Group of icons used for video
    ///   - poll: Group of icons used for polls
    ///   - reaction: Group of images used for reactions
    ///   - delete: Displayed to delete a content
    ///   - report: Displayed to report a content
    ///             Default value is `defaultReport` set in the Icon init.
    ///   - defaultNotAvailable: If set, it will be applied to all notAvailable icons (`Post.notAvailable` and
    ///                          `Comment.notAvailable`) that are not overridden.
    ///   - defaultLikeNotSelected: If set, it will be applied to all likeNotSelected icons (`Post.likeNotSelected`,
    ///                             `Comment.likeNotSelected` and `Reply.likeNotSelected`) that are not overridden.
    ///   - defaultAddPicture: If set, it will be applied to all addPicture icons (`Post.Creation.addPicture`,
    ///                        `Comment.Creation.addPicture` and `Reply.Creation.addPicture`) that are not overridden.
    ///   - defaultDeletePicture: If set, it will be applied to all deletePicture icons (`Post.Creation.deletePicture`,
    ///                           `Comment.Creation.deletePicture` and `Reply.Creation.deletePicture`) that are not
    ///                           overridden.
    ///   - defaultCreateResponse: If set, it will be applied to all createResponse icons (`Comment.Creation.create` and
    ///                            `Reply.Creation.create`) that are not overridden.
    ///   - defaultOpenResponseCreation: If set, it will be applied to all open response creation icons
    ///                                  (`Comment.Creation.open` and `Reply.Creation.open`) that are not overridden.
    public init(
        post: Post = .init(),
        comment: Comment = .init(),
        reply: Reply = .init(),
        video: Video = .init(),
        poll: Poll = .init(),
        reaction: Reaction = .init(),
        delete: UIImage? = nil,
        report: UIImage? = nil,
        defaultNotAvailable: UIImage? = nil,
        defaultLikeNotSelected: UIImage? = nil,
        defaultAddPicture: UIImage? = nil,
        defaultDeletePicture: UIImage? = nil,
        defaultCreateResponse: UIImage? = nil,
        defaultOpenResponseCreation: UIImage? = nil
    ) {
        self.post = post
        self.comment = comment
        self.reply = reply
        self.video = video
        self.poll = poll
        self.reaction = reaction
        self.delete = delete?.prepareForSdkUsage() ?? .Gen.trash
        self.report = report?.prepareForSdkUsage() ?? .Gen.flag

        self.reportIsDefault = report == nil

        if let defaultNotAvailable {
            if post.notAvailableIsDefault {
                self.post.notAvailable = defaultNotAvailable
            }
            if comment.notAvailableIsDefault {
                self.comment.notAvailable = defaultNotAvailable
            }
        }
        if let defaultLikeNotSelected {
            if post.likeNotSelectedIsDefault {
                self.post.likeNotSelected = defaultLikeNotSelected
            }
            if comment.likeNotSelectedIsDefault {
                self.comment.likeNotSelected = defaultLikeNotSelected
            }
            if reply.likeNotSelectedIsDefault {
                self.reply.likeNotSelected = defaultLikeNotSelected
            }
        }
        if let defaultAddPicture {
            if post.creation.addPictureIsDefault {
                self.post.creation.addPicture = defaultAddPicture
            }
            if comment.creation.addPictureIsDefault {
                self.comment.creation.addPicture = defaultAddPicture
            }
            if reply.creation.addPictureIsDefault {
                self.reply.creation.addPicture = defaultAddPicture
            }
        }
        if let defaultDeletePicture {
            if post.creation.deletePictureIsDefault {
                self.post.creation.deletePicture = defaultDeletePicture
            }
            if comment.creation.deletePictureIsDefault {
                self.comment.creation.deletePicture = defaultDeletePicture
            }
            if reply.creation.deletePictureIsDefault {
                self.reply.creation.deletePicture = defaultDeletePicture
            }
        }

        if let defaultCreateResponse {
            if comment.creation.createIsDefault {
                self.comment.creation.create = defaultCreateResponse
            }
            if reply.creation.createIsDefault {
                self.reply.creation.create = defaultCreateResponse
            }
        }

        if let defaultOpenResponseCreation {
            if comment.creation.openIsDefault {
                self.comment.creation.open = defaultOpenResponseCreation
            }
            if reply.creation.openIsDefault {
                self.reply.creation.open = defaultOpenResponseCreation
            }
        }
    }
}

extension OctopusTheme.Assets.Icons.Gamification {
    /// Group of icons used for gamification
    /// - Parameters:
    ///   - badge: The badge of a user. It will be tinted with the color of the level
    ///   - info: Displayed to open the rules
    ///   - rulesHeader: Displayed on the rules
    public init(
        badge: UIImage? = nil,
        info: UIImage? = nil,
        rulesHeader: UIImage? = nil
    ) {
        self.badge = badge?.prepareForSdkUsage() ?? .Gen.Gamification.badge
        self.info = info?.prepareForSdkUsage() ?? .Gen.info
        self.rulesHeader = badge?.prepareForSdkUsage() ?? .Gen.Gamification.rulesHeader
    }
}

extension OctopusTheme.Assets.Icons.Settings {
    /// Group of icons used for the settings
    /// - Parameters:
    ///   - account: Displayed to open the account page (only on Octopus auth mode)
    ///   - help: Displayed to open the help page
    ///   - info: Displayed to open the info page
    ///   - logout: Displayed to logout the current user (only on Octopus auth mode)
    ///   - deleteAccountWarning: Displayed to delete the current user (only on Octopus auth mode)
    public init(
        account: UIImage? = nil,
        help: UIImage? = nil,
        info: UIImage? = nil,
        logout: UIImage? = nil,
        deleteAccountWarning: UIImage? = nil
    ) {
        self.account = account?.prepareForSdkUsage() ?? .Gen.Settings.account
        self.help = help?.prepareForSdkUsage() ?? .Gen.Settings.help
        self.info = info?.prepareForSdkUsage() ?? .Gen.Settings.info
        self.logout = logout?.prepareForSdkUsage() ?? .Gen.Settings.logout
        self.deleteAccountWarning = deleteAccountWarning?.prepareForSdkUsage() ?? .Gen.Settings.warning
    }
}

extension OctopusTheme.Assets.Icons.Profile {
    /// Group of icons used for the profile
    /// - Parameters:
    ///   - addPicture: Displayed in the current user profile, on a default avatar, for the user to add a picture
    ///   - editPicture: Displayed in the profile edit screen, on the user's avatar to change the picture
    ///   - addBio: Displayed in the current user profile, when the user's bio is empty
    ///   - emptyNotifications: Displayed in the current user profile, when the user has no internal notification
    ///   - report: Displayed to report a content
    ///             Default value is `defaultReport` set in the Icon init.
    ///   - notConnected: Displayed as avatar when the user is not connected (error state)
    ///   - blockUser: Displayed to block a user
    public init(
        addPicture: UIImage? = nil,
        editPicture: UIImage? = nil,
        addBio: UIImage? = nil,
        emptyNotifications: UIImage? = nil,
        report: UIImage? = nil,
        notConnected: UIImage? = nil,
        blockUser: UIImage? = nil
    ) {
        self.addPicture = addPicture?.prepareForSdkUsage() ?? .Gen.add
        self.editPicture = editPicture?.prepareForSdkUsage() ?? .Gen.editPicture
        self.addBio = addBio?.prepareForSdkUsage() ?? .Gen.add
        self.emptyNotifications = emptyNotifications?.prepareForSdkUsage() ?? .Gen.bell
        self.report = report?.prepareForSdkUsage() ?? .Gen.flag
        self.notConnected = notConnected?.prepareForSdkUsage() ?? .Gen.notConnected
        self.blockUser = blockUser?.prepareForSdkUsage() ?? .Gen.blockUser

        self.reportIsDefault = report == nil
    }
}

extension OctopusTheme.Assets.Icons.Common {
    /// Group of icons used commonly
    /// - Parameters:
    ///   - radio: Radio button icons
    ///   - checkbox: Checkbox button icons
    ///   - toggle: Toggle button icons.
    ///   - close: Close button
    ///   - moreActions: More actions button
    ///   - listCellNavIndicator: List cell navigation indicator (arrow  right)
    public init(
        radio: OctopusTheme.Assets.Icons.OnOff? = nil,
        checkbox: OctopusTheme.Assets.Icons.OnOff? = nil,
        toggle: OctopusTheme.Assets.Icons.OnOff? = nil,
        close: UIImage? = nil,
        moreActions: UIImage? = nil,
        listCellNavIndicator: UIImage? = nil
    ) {
        self.radio = radio ?? .init(on: .Gen.RadioButton.on, off: .Gen.RadioButton.off)
        self.checkbox = checkbox ?? .init(on: .Gen.CheckBox.on, off: .Gen.CheckBox.off)
        self.toggle = toggle ?? .init(on: .Gen.Toggle.on, off: .Gen.Toggle.off)
        self.close = close?.prepareForSdkUsage() ?? .Gen.close
        self.moreActions = moreActions?.prepareForSdkUsage() ?? .Gen.more
        self.listCellNavIndicator = listCellNavIndicator?.prepareForSdkUsage() ?? .Gen.cellNavIndicator
    }
}

extension OctopusTheme.Assets.Icons {
    /// Constructor of the set of icons used inside the SDK.
    ///
    /// Icons should be squared, ideally 24x24 with its drawn content making 14.5x14.5
    /// (i.e. transparent borders of 4.75). If you have a different size, it is ok but these ratio should be kept to be
    /// correctly displayed in the Octopus Community UI.
    /// Icons will be tinted, so colors of the asset will be ignored.
    /// If not square, they will be displayed with a fit mode, so the icon might be smaller that what you expect.
    ///
    /// If you do not override an icon, it will be displayed with an asset provided by the Octopus SDK.
    ///
    /// Some icons will be almost always the same even if they are not in the same group. It is the case for example of
    /// the `report` icon where the user can report a profile or a content. To easilly change all icons with the same
    /// meaning, we've added some defaultXXX parameter that will be used for these icons if you don't provide an asset
    /// for the specific icon.
    /// Keeping the previous `report` example:
    /// ```
    /// // Full custo, Content.report = asset1, Profile.report = asset2:
    /// Icons(content: Content(report: asset1), profile(report: asset2))
    ///
    /// // Half custo, Content.report = asset0, Profile.report = asset2:
    /// Icons(profile(report: asset2), defaultReport: asset0)
    ///
    /// // Small custo: Content.report = asset0, Profile.report = asset0:
    /// Icons(defaultReport: asset0)
    /// ```
    ///
    /// - Parameters:
    ///   - groups: Group of icons used for groups
    ///   - content: Group of icons used for content (posts, comments, replies...)
    ///   - profile: Group of icons used for profile
    ///   - gamification: Group of icons used for gamification
    ///   - settings: Group of icons used for the settings
    ///   - common: Common icons
    ///   - defaultReport: If set, it will be applied to all report icons (`Content.report` and `Profile.report`)
    ///                    that are not overridden.
    ///
    /// - Note: as the icons are linked to the UI and the UI can change quite often, this API might change often,
    /// some icons won't be used anymore and will be quickly deprecated.
    public init(
        groups: Groups = .init(),
        content: Content = .init(),
        profile: Profile = .init(),
        gamification: Gamification = .init(),
        settings: Settings = .init(),
        common: Common = .init(),
        defaultReport: UIImage? = nil
    ) {
        self.groups = groups
        self.content = content
        self.profile = profile
        self.gamification = gamification
        self.settings = settings
        self.common = common

        if let defaultReport {
            if content.reportIsDefault {
                self.content.report = defaultReport
            }
            if profile.reportIsDefault {
                self.profile.report = defaultReport
            }
        }
    }
}
