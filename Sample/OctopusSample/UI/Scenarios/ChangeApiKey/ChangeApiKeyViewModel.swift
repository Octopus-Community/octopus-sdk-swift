//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that shows how to change the API key, if you want to switch communities
class ChangeApiKeyViewModel: ObservableObject {
    var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    private var storage = [AnyCancellable]()

    // Not needed in your app, just here to know if the SDK was configured in SSO or not
    private var latestConfig: SDKConfig?

    init() {
        latestConfig = SDKConfigManager.instance.sdkConfig
    }

    func changeApiKey() {
        // First, disconnect the user if you have one
        disconnectUserIfNeeded()

        // Then, change the API key by initializing a new SDK. Make sure that there is only one instance alive
        // (i.e. do not keep the former instance, the one with the previous API key)
        if DefaultValuesProvider.internalDemoMode {
            // only used for internal demo mode, please ignore
            OctopusSDKProvider.instance.initializeSDKForInternalUsage()
        } else {
            // You should re-init the OctopusSDK with another API key
            // (commented here because we do not have another APIKey)
            //OctopusSDKProvider.instance.octopus = try! OctopusSDK(apiKey: newApiKey, connectionMode: ...)
        }
        // We post a notification in order to reload any OctopusUI with the new OctopusSDK and to re-connect the user
        NotificationCenter.default.post(name: .apiKeyChanged, object: nil)

        // Finally, reconnect your user if you have one.
        // (in the samples, it is done using the notification .apiKeyChanged, used by AppUserManager)

        // Not needed in your app, just here to know if the SDK was configured in SSO or not
        latestConfig = SDKConfigManager.instance.sdkConfig
    }

    func disconnectUserIfNeeded() {
        switch latestConfig?.authKind {
        case .octopus: return
        default: break // if config is nil, or if sso, we can continue
        }

        OctopusSDKProvider.instance.octopus.disconnectUser()
    }
}
