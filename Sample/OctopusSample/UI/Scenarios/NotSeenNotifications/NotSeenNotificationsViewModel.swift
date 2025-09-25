//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that provides an Octopus SDK with Octopus auth connection mode and it exposes the number of
/// not seen internal notifications. It also has a function to update that count.
class NotSeenNotificationsViewModel: ObservableObject {
    @Published private(set) var octopus: OctopusSDK?
    @Published private(set) var notSeenNotificationsCount: Int = 0

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)

        octopusSDKProvider.$octopus
            .map {
                guard let octopus = $0 else {
                    return Just<Int>(0).eraseToAnyPublisher()
                }
                return octopus.$notSeenNotificationsCount.eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] in
                notSeenNotificationsCount = $0
            }.store(in: &storage)
    }

    func updateNotSeenNotificationsCount() {
        Task {
            try? await octopus?.updateNotSeenNotificationsCount()
        }
    }
}
