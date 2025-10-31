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
    let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus
    @Published private(set) var notSeenNotificationsCount: Int = 0

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        octopus.$notSeenNotificationsCount
            .sink { [unowned self] in
                notSeenNotificationsCount = $0
            }.store(in: &storage)
    }

    func updateNotSeenNotificationsCount() {
        Task {
            try? await octopus.updateNotSeenNotificationsCount()
        }
    }
}
