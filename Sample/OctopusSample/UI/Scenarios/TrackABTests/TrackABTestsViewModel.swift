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
    @Published private(set) var octopus: OctopusSDK?
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

        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)

        // Each time octopus changes or canAccessCommunity, update the SDK with the new value
        // This is done as soon as the Octopus SDK is set (and you should so).
        Publishers.CombineLatest(
            octopusSDKProvider.$octopus,
            $canAccessCommunity
        )
        .sink { [unowned self] octopus, canAccessCommunity in
            guard isDisplayed else { return }
            guard let octopus else { return }
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
