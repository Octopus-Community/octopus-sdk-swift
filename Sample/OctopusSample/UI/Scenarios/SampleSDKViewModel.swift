//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A generic view model that provides the Octopus SDK to the Sample screens
@MainActor
class SampleSDKViewModel: ObservableObject {
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
