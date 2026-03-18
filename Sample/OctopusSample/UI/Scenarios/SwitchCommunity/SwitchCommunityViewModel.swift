//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that shows how to change the API key, if you want to switch communities
@MainActor
class SwitchCommunityViewModel: ObservableObject {
    var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    @Published private(set) var isLoading = false
    @Published var error: Error?

    private var storage = [AnyCancellable]()

    func switchCommunity() {
        Task {
            await switchCommunity()
        }
    }

    private func switchCommunity() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if DefaultValuesProvider.internalDemoMode {
                // only used for internal demo mode, please ignore
                try await OctopusSDKProvider.instance.switchCommunityFromConfig()
            } else {
                // You should re-init the OctopusSDK with another API key
                // (commented here because we do not have another APIKey)
                // try await OctopusSDKProvider.instance.octopus.switchCommunity(apiKey: newApiKey, connectionMode: ...)
            }

            /// Make sure to **reconnect the user** and reload any existing OctopusHomeScreen
            /// In the sample, we do that by posting a notification.
            NotificationCenter.default.post(name: .apiKeyChanged, object: nil)
        } catch {
            self.error = error
        }
    }
}
