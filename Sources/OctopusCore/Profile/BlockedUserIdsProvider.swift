//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection

protocol BlockedUserIdsProvider {
    var blockedUserIdsPublisher: AnyPublisher<[String], Never> { get }
    var blockedUserIds: [String] { get }

    func start()
    func stop()
}

extension Injected {
    static let blockedUserIdsProvider = Injector.InjectedIdentifier<BlockedUserIdsProvider>()
}

class BlockedUserIdsProviderDefault: BlockedUserIdsProvider, InjectableObject {
    static let injectedIdentifier = Injected.blockedUserIdsProvider

    var blockedUserIdsPublisher: AnyPublisher<[String], Never> {
        $blockedUserIds
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    @Published private(set) var blockedUserIds = [String]()

    private let injector: Injector
    private var storage = [AnyCancellable]()

    init(injector: Injector) {
        self.injector = injector
    }

    func start() {
        injector.getInjected(identifiedBy: Injected.profileRepository)
            .$profile
            .map {
                guard let profile = $0 else { return [] }
                return profile.blockedProfileIds
            }
            .removeDuplicates()
            .sink { [unowned self] in
                blockedUserIds = $0
            }.store(in: &storage)
    }

    func stop() {
        storage = []
    }
}
