//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct WritableReply: Sendable {
    public let commentId: String
    public let text: String?
    public internal(set) var imageData: Data?

    public init(commentId: String, text: String?, imageData: Data?) {
        self.commentId = commentId
        self.text = text
        self.imageData = imageData
    }
}

extension WritableReply {
    func rwOctoObject() -> Com_Octopuscommunity_RwOctoObject {
        return .with {
            $0.parentID = commentId
            $0.pressedEnterAt = Date().timestampMs
            $0.content = .with {
                $0.reply = .with {
                    if let text {
                        $0.text = text
                    }
                    if let imageData {
                        $0.media = .with {
                            $0.images = [
                                .with { $0.file = .bytes(imageData) }
                            ]
                        }
                    }
                }
            }
        }
    }
}
