//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
@_spi(OctopusInternalTesting) import Octopus

/// View model of ScreenStatesView.
///
/// Applies a DEBUG-only override of the SDK's connectivity, so the offline screen states can be
/// exercised in the simulator (OCT-1617). A simulator always reports a connection, so without this
/// the empty/error states, their Retry and the no-connection toast are only reachable on a device in
/// airplane mode — which is how every one of their defects was found instead of being caught here.
@MainActor
class ScreenStatesViewModel: ObservableObject {
    @Published private(set) var isOffline = false

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func goOffline() {
        octopus.debugOverrideConnectionAvailable(false)
        isOffline = true
    }

    func goOnline() {
        octopus.debugOverrideConnectionAvailable(true)
        isOffline = false
    }

    func clearOverride() {
        octopus.debugOverrideConnectionAvailable(nil)
        isOffline = false
    }
}
