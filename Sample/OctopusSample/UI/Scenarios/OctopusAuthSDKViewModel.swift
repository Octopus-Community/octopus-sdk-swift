//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A generic view model that provides an Octopus SDK with Octopus auth connection mode
@MainActor
class OctopusAuthSDKViewModel: ObservableObject {
    var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }
    @Published private(set) var authorizationStatus: UNAuthorizationStatus?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance
    private let notificationManager = NotificationManager.instance

    init() {
        notificationManager.$authorizationStatus
            .sink { [unowned self] in
                authorizationStatus = $0
            }.store(in: &storage)
    }

    func askForNotificationPermission() {
        notificationManager.requestForPushNotificationPermission()
    }
}
