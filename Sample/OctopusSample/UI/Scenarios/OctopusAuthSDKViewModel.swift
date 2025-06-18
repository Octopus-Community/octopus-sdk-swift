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
    @Published private(set) var octopus: OctopusSDK?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance
    private let notificationManager = NotificationManager.instance

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)

        notificationManager.$authorizationStatus
            .sink { [unowned self] in
                authorizationStatus = $0
            }.store(in: &storage)
    }

    func createSDK() {
        octopusSDKProvider.createSDK(
            connectionMode: .octopus(deepLink: "com.octopuscommunity.sample://magic-link"))
    }

    func askForNotificationPermission() {
        notificationManager.requestForPushNotificationPermission()
    }
}
