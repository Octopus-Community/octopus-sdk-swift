//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct WritablePoll: Sendable, Equatable {
    public struct Option: Sendable, Equatable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }
    public let options: [Option]

    public init(options: [Option]) {
        self.options = options
    }
}

public struct WritablePost: Sendable, Equatable {
    public enum Attachment: Sendable, Equatable {
        case image(Data)
        case poll(WritablePoll)
    }
    public let text: String
    public internal(set) var attachment: Attachment?
    public let parentId: String

    public init(topicId: String, text: String, attachment: Attachment?) {
        self.parentId = topicId
        self.text = text
        self.attachment = attachment
    }
}

extension WritablePost {
    func rwOctoObject(imageIsCompressed: Bool) -> Com_Octopuscommunity_RwOctoObject {
        return .with {
            $0.parentID = parentId
            $0.pressedEnterAt = Date().timestampMs
            $0.content = .with {
                $0.post = .with {
                    $0.text = text
                    switch attachment {
                    case let .image(imageData):
                        $0.media = .with {
                            $0.images = [
                                .with {
                                    $0.file = .bytes(imageData)
                                    $0.isOptimized = imageIsCompressed
                                }
                            ]
                        }
                    case let .poll(poll):
                        $0.poll = .with {
                            $0.answers = poll.options.map { option in
                                .with {
                                    $0.text = option.text
                                }
                            }
                        }
                    case .none: break
                    }
                }
            }
        }
    }
}
