//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusUI

/// Internal-demo-only preference: which `OctopusNavigationMode` the sample uses when it presents the
/// Octopus UI inside a modal. Lets QA flip between `.automatic` (legacy `NavigationView`) and
/// `.navigationStack` (real `NavigationStack` on iOS 16+) to compare behavior on the same build.
enum SampleNavigationMode: String, CaseIterable, Identifiable {
    case automatic
    case navigationStack

    var id: String { rawValue }

    var displayableString: String {
        switch self {
        case .automatic: return "Automatic"
        case .navigationStack: return "NavigationStack"
        }
    }

    var octopusNavigationMode: OctopusNavigationMode {
        switch self {
        case .automatic: return .automatic
        case .navigationStack: return .navigationStack
        }
    }
}

/// Persists the chosen `SampleNavigationMode` in UserDefaults so every modal entry point of the sample
/// reads the same value. For internal testing only.
class NavigationModeManager: ObservableObject {
    static let instance = NavigationModeManager()

    private let storageKey = "sampleNavigationMode"

    @Published var mode: SampleNavigationMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: storageKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        mode = raw.flatMap(SampleNavigationMode.init(rawValue:)) ?? .automatic
    }
}
