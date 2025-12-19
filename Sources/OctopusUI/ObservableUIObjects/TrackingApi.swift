//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

final class TrackingApi: ObservableObject {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func trackTranslationButtonHit(translationDisplayed: Bool) {
        octopus.core.trackingRepository.trackTranslationButtonHit(translationDisplayed: translationDisplayed)
    }
}
