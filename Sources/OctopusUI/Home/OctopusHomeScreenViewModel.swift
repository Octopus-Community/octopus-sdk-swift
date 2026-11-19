//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore
import os

@MainActor
class OctopusHomeScreenViewModel: ObservableObject {

    @Published private(set) var mainFlowPath = MainFlowPath()
    @Published private(set) var displayOnboarding = false
    @Published private(set) var displayCommunityAccessDenied = false
    @Published private(set) var overridenLocale: Locale?
    /// The identity of the navigation stack: the view builds a new stack each time it changes.
    @Published private(set) var navigationStackId = 0

    private var storage = [AnyCancellable]()

    init(userConfigPublisher: AnyPublisher<UserConfig?, Never>,
         overridenLocalePublisher: AnyPublisher<Locale?, Never>) {
        userConfigPublisher.sink { [unowned self] userConfig in
            guard userConfig?.canAccessCommunity ?? true else {
                displayOnboarding = false
                // Only when the access is taken away: the access denied screen reads the access again by itself,
                // and a stack built again each time would create it again, and read again, without end.
                guard !displayCommunityAccessDenied else { return }
                displayCommunityAccessDenied = true
                // The access denied screen stands at the root: a user deeper in the community (a post, a profile)
                // would stay on a screen whose every call is refused, and only find it on their way back.
                // Emptying the path was seen not to be enough on a device: the pushed screen, which the refused
                // call makes show an error at that moment, stayed. A new stack leaves nothing of the previous one.
                if !mainFlowPath.path.isEmpty {
                    mainFlowPath.path = []
                }
                mainFlowPath.reportTarget = nil
                navigationStackId += 1
                return
            }
            displayCommunityAccessDenied = false
        }.store(in: &storage)

        overridenLocalePublisher.sink { [unowned self] in
            overridenLocale = $0
        }.store(in: &storage)
    }

    convenience init(octopus: OctopusSDK) {
        self.init(userConfigPublisher: octopus.core.configRepository.userConfigPublisher,
                  overridenLocalePublisher: octopus.core.languageRepository.$overridenLocale.eraseToAnyPublisher())
    }
}
