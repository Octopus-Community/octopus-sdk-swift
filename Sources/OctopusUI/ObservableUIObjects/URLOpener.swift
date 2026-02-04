//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit
import Octopus

@MainActor
final class URLOpener: ObservableObject {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func open(url: URL) {
        switch octopus.onNavigateToURLCallback?(url) {
        case .handledByApp:
            // nothing to do as the link is handled by the app
            break
        case .handledByOctopus, .none:
            // if handledByOctopus or if no callback has been registered, open the link from Octopus
            UIApplication.shared.open(url)
        }
    }
}
