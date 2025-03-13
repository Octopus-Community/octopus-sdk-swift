//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

public struct WritablePost: Sendable, Equatable {
    public let text: String
    public internal(set) var imageData: Data?
    public var parentId: String

    public init(topicId: String, text: String, imageData: Data?) {
        self.parentId = topicId
        self.text = text
        self.imageData = imageData
    }
}

extension WritablePost {
    func rwOctoObject() -> Com_Octopuscommunity_RwOctoObject {
        return .with {
            $0.parentID = parentId
            $0.pressedEnterAt = Date().timestampMs
            $0.content = .with {
                $0.post = .with {
                    $0.text = text
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
