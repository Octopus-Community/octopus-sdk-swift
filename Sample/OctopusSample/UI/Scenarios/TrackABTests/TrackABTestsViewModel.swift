//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that provides an Octopus SDK and sets as soon as possible whether the user has access to the community
/// UI.
class TrackABTestsViewModel: ObservableObject {
    let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus
    @Published var canAccessCommunity: Bool

    private var storage = [AnyCancellable]()
    private let canAccessCommunityKey = "canAccessCommunity"

    private let octopusSDKProvider = OctopusSDKProvider.instance

    private var isDisplayed = false

    init() {
        canAccessCommunity = UserDefaults.standard.bool(forKey: canAccessCommunityKey)

        $canAccessCommunity
            .removeDuplicates()
            .sink { [unowned self] in
                // store the new value in the user defaults
                UserDefaults.standard.set($0, forKey: canAccessCommunityKey)
        }.store(in: &storage)

        // Update the sdk with the canAccessCommunity at init and every time the value changes.
        $canAccessCommunity
            .sink { [unowned self] canAccessCommunity in
                guard isDisplayed else { return }
                octopus.track(hasAccessToCommunity: canAccessCommunity)
            }.store(in: &storage)
    }

    func createSDK() {
        isDisplayed = true
    }

    func resetSDK() {
        canAccessCommunity = true
        isDisplayed = false
    }
}
