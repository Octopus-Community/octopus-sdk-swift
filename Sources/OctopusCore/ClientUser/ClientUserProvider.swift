//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection

extension Injected {
    static let clientUserProvider = Injector.InjectedIdentifier<ClientUserProvider>()
}

class ClientUserProvider: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.clientUserProvider

    @Published private(set) var clientUser: ClientUser?

    private let userDataStorage: UserDataStorage
    private var storage: Set<AnyCancellable> = []

    init(connectionMode: ConnectionMode, injector: Injector) {
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)

        if case .sso = connectionMode {
            let clientUserProfileDatabase = injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
            userDataStorage.$clientUserData
                .receive(on: DispatchQueue.main)
                .map { clientUserData in
                    guard let clientUserData else {
                        return Just<ClientUser?>(nil).eraseToAnyPublisher()
                    }
                    return clientUserProfileDatabase.profilePublisher(clientUserId: clientUserData.id)
                        .replaceError(with: nil)
                        .map {
                            guard let clientUserProfile = $0 else { return nil }
                            return ClientUser(userId: clientUserData.id,
                                              profile: clientUserProfile)
                        }
                        .eraseToAnyPublisher()
                }
                .switchToLatest()
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [unowned self] in
                    self.clientUser = $0
                }.store(in: &storage)
        }
    }

}
