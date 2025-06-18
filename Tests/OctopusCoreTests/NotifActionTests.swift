//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct NotifActionTests {
    @Test func stringToArrayOfScreens() {
        #expect(
            "post/POST_ID".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: false)]
        )
        #expect(
            "post/POST_ID?commentId=COMMENT_ID".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: "COMMENT_ID", scrollToMostRecentComment: false)]
        )
        #expect(
            "post/POST_ID?scrollToLatestComment=true".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: true)]
        )
        #expect(
            "post/POST_ID?commentId=COMMENT_ID&scrollToLatestComment=true".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: "COMMENT_ID", scrollToMostRecentComment: true)]
        )
        #expect(
            "comment/COMMENT_ID".toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: nil)]
        )
        #expect(
            "comment/COMMENT_ID?replyId=REPLY_ID".toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: "REPLY_ID")]
        )
        #expect(
            "post/POST_ID?commentId=COMMENT_ID&scrollToLatestComment=true/comment/COMMENT_ID?replyId=REPLY_ID".toArrayOfScreens ==
            [
                .postDetail(postId: "POST_ID", commentToScrollTo: "COMMENT_ID", scrollToMostRecentComment: true),
                .commentDetail(commentId: "COMMENT_ID", replyToScrollTo: "REPLY_ID")
            ]
        )
    }

    @Test func weirdStringToArrayOfScreens() {
        // check that an unknown token does not break the already parsed part
        #expect(
            "post/POST_ID/comment".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: false)]
        )
        // Check that an unknown query param is ok
        #expect(
            "post/POST_ID?toto=tata".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: false)]
        )
        #expect(
            "post/POST_ID?commentId=COMMENT_ID&toto=tata".toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: "COMMENT_ID", scrollToMostRecentComment: false)]
        )
        // Check that an non valid path is giving an empty array
        #expect(
            "".toArrayOfScreens ==
            []
        )
        #expect(
            "post".toArrayOfScreens ==
            []
        )
    }

    // check that receiving protobuf LinkToOctoObject is translated into the correct array of OctoScreen
    @Test func protoToArrayOfScreens() {
        // open the post
        var protoArr: [Com_Octopuscommunity_Notification.Action.LinkToOctoObject] = [
            .with {
                $0.octoObjectID = "POST_ID"
                $0.content = .post
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            [.postDetail(postId: "POST_ID", commentToScrollTo: nil, scrollToMostRecentComment: false)]
        )

        // open the comment
        protoArr = [
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .comment
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: nil)]
        )

        // open the comment and scroll to a reply
        protoArr = [
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .comment
            },
            .with {
                $0.octoObjectID = "REPLY_ID"
                $0.content = .reply
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: "REPLY_ID")]
        )

        // check that having a post information when there is a reply is not changing the output
        // (this is the current product behavior, it might change in the future)
        protoArr = [
            .with {
                $0.octoObjectID = "POST_ID"
                $0.content = .post
            },
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .comment
            },
            .with {
                $0.octoObjectID = "REPLY_ID"
                $0.content = .reply
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: "REPLY_ID")]
        )
    }

    // check that receiving an unexpected protobuf LinkToOctoObject is translated into the correct array of OctoScreen
    @Test func weirdProtoToArrayOfScreens() {
        // empty array should return a nil storable string
        var protoArr: [Com_Octopuscommunity_Notification.Action.LinkToOctoObject] = [
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            nil
        )

        // when the only LinkToOctoObject is either undefined or UNRECOGNIZED, it should return a nil storable string
        protoArr = [
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .undefined
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            nil
        )
        protoArr = [
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .UNRECOGNIZED(1000)
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            nil
        )

        // when a part is undefined or UNRECOGNIZED, it should not impact the returned value
        protoArr = [
            .with {
                $0.octoObjectID = "COMMENT_ID"
                $0.content = .comment
            },
            .with {
                $0.octoObjectID = "UNKNOWN_DATA"
                $0.content = .undefined
            },
            .with {
                $0.octoObjectID = "REPLY_ID"
                $0.content = .reply
            },
            .with {
                $0.octoObjectID = "UNKNOWN_DATA"
                $0.content = .UNRECOGNIZED(1000)
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            [.commentDetail(commentId: "COMMENT_ID", replyToScrollTo: "REPLY_ID")]
        )

        // Not having the comment info when having a reply should return nil
        protoArr = [
            .with {
                $0.octoObjectID = "REPLY_ID"
                $0.content = .reply
            }
        ]
        #expect(
            protoArr.storableString?.toArrayOfScreens ==
            nil
        )
    }
}

private extension String {
    var toArrayOfScreens: [NotifAction.OctoScreen]? {
        [NotifAction.OctoScreen](from: self)
    }
}
