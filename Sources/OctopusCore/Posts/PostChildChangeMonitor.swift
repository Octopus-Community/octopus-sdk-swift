//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection

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
                try await postsDatabase.incrementChildCount(by: 1, postId: createdComment.parentId)
            }
        }.store(in: &storage)

        commentsRepository.commentDeletedPublisher.sink { [unowned self] deletedComment in
            guard let deletedComment else { return }
            Task {
                try await postsDatabase.incrementChildCount(by: -1, postId: deletedComment.parentId)
            }
        }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
