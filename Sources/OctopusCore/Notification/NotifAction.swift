//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import os

public enum NotifAction: Equatable {
    public enum OctoScreen: Equatable {
        case postDetail(postId: String, commentToScrollTo: String?, scrollToMostRecentComment: Bool)
        case commentDetail(commentId: String, replyToScrollTo: String?)
    }

    case open(path: [OctoScreen])
}

private let tokenSeparator = Character("/")
private let firstQueryParamSeparator = Character("?")
private let subsequentQueryParamSeparator = Character("&")
private let valueQueryParamSeparator = Character("=")
private let postKey = "post"
private let commentKey = "comment"
private let commentIdParamKey = "commentId"
private let scrollToLatestCommentKey = "scrollToLatestComment"
private let replyIdParamKey = "replyId"

extension Array where Element == NotifAction.OctoScreen {
    init(from linkPath: String) {
        func extractIdAndQueryParams(from str: String) -> (id: String, queryParams: [String: String]) {
            let parts = str.split(separator: firstQueryParamSeparator)
            let id = String(parts[0])
            let queryParamsStr = parts.count > 1 ? parts[1] : ""
            var queryParams: [String: String] = [:]
            for pair in queryParamsStr.split(separator: subsequentQueryParamSeparator) {
                let parts = pair.split(separator: valueQueryParamSeparator, maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    queryParams[parts[0]] = parts[1]
                }
            }

            return (id: id, queryParams: queryParams)
        }

        let pathParts = linkPath.split(separator: tokenSeparator)

        var result: [NotifAction.OctoScreen] = []
        var index = 0

        while index < pathParts.count {
            let segment = pathParts[index]
            switch segment {
            case postKey:
                guard index + 1 < pathParts.count else {
                    if #available(iOS 14, *) { Logger.notifs.debug("Error, post token without an id after in \(linkPath)") }
                    index += 1
                    break
                }
                let postIdPart = pathParts[index + 1]
                let postIdData = extractIdAndQueryParams(from: String(postIdPart))
                let postId = postIdData.id
                let commentId = postIdData.queryParams[commentIdParamKey]
                let scrollToLatest = postIdData.queryParams[scrollToLatestCommentKey] != nil
                result.append(.postDetail(postId: postId, commentToScrollTo: commentId,
                                          scrollToMostRecentComment: scrollToLatest))
                index += 2
            case commentKey:
                guard index + 1 < pathParts.count else {
                    if #available(iOS 14, *) { Logger.notifs.debug("Error, comment token without an id after in \(linkPath)") }
                    index += 1
                    break
                }
                let commentIdPart = pathParts[index + 1]
                let commentIdData = extractIdAndQueryParams(from: String(commentIdPart))
                let commentId = commentIdData.id
                let replyId = commentIdData.queryParams[replyIdParamKey]
                result.append(.commentDetail(commentId: commentId, replyToScrollTo: replyId))
                index += 2
            default:
                if #available(iOS 14, *) { Logger.notifs.debug("Error, token \(segment) not expected") }
                index += 1
            }
        }

        self = result
    }
}

extension Array where Element == Com_Octopuscommunity_Notification.Action.LinkToOctoObject {
    var storableString: String? {
        guard let lastContentToOpen = last(where: { $0.content.isKnown }) else { return nil }
        switch lastContentToOpen.content {
        case .post:
            return "\(postKey)\(tokenSeparator)\(lastContentToOpen.octoObjectID)"
        case .comment:
            return "\(commentKey)\(tokenSeparator)\(lastContentToOpen.octoObjectID)"
        case .reply:
            // we need to know which is the parent comment for the reply
            guard let comment = last(where: { $0.content == .comment }) else { return nil }
            return "\(commentKey)\(tokenSeparator)\(comment.octoObjectID)" +
            "\(firstQueryParamSeparator)\(replyIdParamKey)\(valueQueryParamSeparator)\(lastContentToOpen.octoObjectID)"
        case .undefined, .UNRECOGNIZED:
            // should not happen because lastContentToOpen is the last "known"
            return nil
        }
    }
}

private extension Com_Octopuscommunity_Notification.Action.ContentEntity {
    /// Gets whether the type is known or not (i.e. not undefined nor unrecognized)
    var isKnown: Bool {
        switch self {
        case .undefined, .UNRECOGNIZED: return false
        default:                        return true
        }
    }
}
