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
    /// The text of the button. When `perLanguageLabels` is set, it is the label of their default language.
    public let label: String
    /// The labels the app gives per language. `nil` when the label is translated automatically.
    public let perLanguageLabels: PerLanguageLabels?

    public init(url: URL, label: String, perLanguageLabels: PerLanguageLabels? = nil) {
        self.url = url
        self.label = label
        self.perLanguageLabels = perLanguageLabels
    }
}

public struct WritablePost: Sendable, Equatable {
    /// The text of the post. The repository sends a blank text empty when the post may omit it.
    public internal(set) var text: String
    /// The pictures attached to the post, in display order. The repository swaps in the resized bytes before
    /// sending.
    public internal(set) var images: [Data]
    /// The poll attached to the post. A post may carry images and a poll together.
    public let poll: WritablePoll?
    public let parentId: String
    public let cta: WritableCTA?

    public init(topicId: String, text: String, images: [Data] = [], poll: WritablePoll? = nil,
                cta: WritableCTA? = nil) {
        self.parentId = topicId
        self.text = text
        self.images = images
        self.poll = poll
        self.cta = cta
    }
}

extension WritablePost {
    /// - Parameters:
    ///   - uploadIds: the upload id of each image of `images`, in the same order. The photos are not sent inline:
    ///     they were uploaded beforehand (already resized) and the post references them by id.
    ///   - imagesAreOptimized: for each image, in the same order, whether the resizer recompressed it (the
    ///     `isOptimized` flag sent to the server). A missing entry means not optimized.
    func rwOctoObject(uploadIds: [String], imagesAreOptimized: [Bool]) -> Com_Octopuscommunity_RwOctoObject {
        return .with {
            $0.parentID = parentId
            $0.pressedEnterAt = Date().timestampMs
            $0.content = .with {
                $0.post = .with {
                    $0.text = text
                    if !uploadIds.isEmpty {
                        $0.media = .with {
                            $0.images = uploadIds.enumerated().map { index, uploadId in
                                .with {
                                    $0.uploadID = uploadId
                                    $0.isOptimized = imagesAreOptimized.indices.contains(index)
                                        && imagesAreOptimized[index]
                                }
                            }
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
                            cta.perLanguageLabels?.fill(&$0)
                        }
                    }
                }
            }
        }
    }
}
