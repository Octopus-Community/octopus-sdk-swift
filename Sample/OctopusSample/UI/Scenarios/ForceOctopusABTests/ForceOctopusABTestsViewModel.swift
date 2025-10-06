//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// View model of ForceOctopusABTestsView
class ForceOctopusABTestsViewModel: ObservableObject {
    @Published private(set) var octopus: OctopusSDK?
    @Published var hasCommunityAccess = false
    @Published var error: Error?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
                hasCommunityAccess = octopus?.hasAccessToCommunity ?? false
            }.store(in: &storage)

        octopusSDKProvider.$octopus
            .map {
                guard let octopus = $0 else {
                    return Just<Bool>(false).eraseToAnyPublisher()
                }
                return octopus.$hasAccessToCommunity.eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] in
                hasCommunityAccess = $0
            }.store(in: &storage)
    }

    func overrideCommunityAccess(enabled: Bool) {
        Task {
            await overrideCommunityAccess(enabled: enabled)
        }
    }

    private func overrideCommunityAccess(enabled: Bool) async {
        do {
            try await octopus?.overrideCommunityAccess(enabled)
        } catch {
            self.error = error
        }
    }
}
