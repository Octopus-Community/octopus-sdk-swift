//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

@MainActor
final class LanguageManager: ObservableObject {
    @Published private(set) var overridenLocale: Locale?

    private let octopus: OctopusSDK
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        octopus.core.languageRepository.$overridenLocale.sink { [unowned self] in
            overridenLocale = $0
        }.store(in: &storage)
    }

}
