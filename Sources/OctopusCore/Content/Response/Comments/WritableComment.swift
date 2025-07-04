//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct WritableComment: Sendable {
    public let postId: String
    public let text: String?
    public internal(set) var imageData: Data?
    /// Whether the image is compressed or not. Only used internally after the ImgeResizer has been used.
    var isImageCompressed = false

    public init(postId: String, text: String?, imageData: Data?) {
        self.postId = postId
        self.text = text
        self.imageData = imageData
    }
}

extension WritableComment {
    func rwOctoObject() -> Com_Octopuscommunity_RwOctoObject {
        return .with {
            $0.parentID = postId
            $0.pressedEnterAt = Date().timestampMs
            $0.content = .with {
                $0.comment = .with {
                    if let text {
                        $0.text = text
                    }
                    if let imageData {
                        $0.media = .with {
                            $0.images = [
                                .with {
                                    $0.file = .bytes(imageData)
                                    $0.isOptimized = isImageCompressed
                                }
                            ]
                        }
                    }
                }
            }
        }
    }
}
