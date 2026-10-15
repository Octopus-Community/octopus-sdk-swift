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

public struct WritableCTA: Sendable, Equatable {
    public let url: URL
    public let label: String

    public init(url: URL, label: String) {
        self.url = url
        self.label = label
    }
}

public struct WritablePost: Sendable, Equatable {
    /// The text of the post. The repository sends a blank text empty when the post may omit it.
    public internal(set) var text: String
    /// The picture attached to the post. The repository swaps in the resized bytes before sending.
    public internal(set) var image: Data?
    /// The poll attached to the post. A post may carry an image and a poll together.
    public let poll: WritablePoll?
    public let parentId: String
    public let cta: WritableCTA?

    public init(topicId: String, text: String, image: Data? = nil, poll: WritablePoll? = nil,
                cta: WritableCTA? = nil) {
        self.parentId = topicId
        self.text = text
        self.image = image
        self.poll = poll
        self.cta = cta
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
                    if let image {
                        $0.media = .with {
                            $0.images = [
                                .with {
                                    $0.file = .bytes(image)
                                    $0.isOptimized = imageIsCompressed
                                }
                            ]
                        }
                    }
                    if let poll {
                        $0.poll = .with {
                            $0.answers = poll.options.map { option in
                                .with {
                                    $0.text = option.text
                                }
                            }
                        }
                    }
                    if let cta {
                        $0.cta = .with {
                            $0.text = cta.label
                            $0.targetLink = cta.url.absoluteString
                        }
                    }
                }
            }
        }
    }
}
