//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let postChildChangeMonitor = Injector.InjectedIdentifier<PostChildChangeMonitor>()
}

class PostChildChangeMonitor: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.postChildChangeMonitor

    private let commentsRepository: CommentsRepository
    private let postsDatabase: PostsDatabase

    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        commentsRepository = injector.getInjected(identifiedBy: Injected.commentsRepository)
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
    }

    func start() {
        commentsRepository.commentSentPublisher.sink { [unowned self] createdComment in
            Task {
                do {
                    try await postsDatabase.incrementChildCount(by: 1, contentId: createdComment.parentId)
                } catch {
                    if #available(iOS 14, *) {
                        Logger.comments.debug("Error while incrementing the post child count: \(error)")
                    }
                }
            }
        }.store(in: &storage)

        commentsRepository.commentDeletedPublisher.sink { [unowned self] deletedComment in
            guard let deletedComment else { return }
            Task {
                do {
                    try await postsDatabase.incrementChildCount(by: -1, contentId: deletedComment.parentId)
                } catch {
                    if #available(iOS 14, *) {
                        Logger.comments.debug("Error while decrementing the post child count: \(error)")
                    }
                }
            }
        }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
