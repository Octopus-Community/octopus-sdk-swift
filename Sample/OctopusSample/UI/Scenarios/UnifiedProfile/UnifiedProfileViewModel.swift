//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import Foundation

/// The Unified Profile scenario: the switch that sets both inputs at once, and the "Backend flag override" controls
/// that move the community flag alone. Both read and write the shared `UnifiedProfileManager`, so the Config
/// screen's switch and this scenario never disagree.
@MainActor
class UnifiedProfileViewModel: ObservableObject {
    /// The "Backend flag override" choices, as on Android.
    enum Mode: Int, CaseIterable, Identifiable {
        case backend = 0
        case forceActive = 1
        case forceInactive = 2

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .backend: "Use backend value"
            case .forceActive: "Force flag on"
            case .forceInactive: "Force flag off"
            }
        }

        var testId: String {
            switch self {
            case .backend: "expose-override-backend"
            case .forceActive: "expose-override-on"
            case .forceInactive: "expose-override-off"
            }
        }

        var overrideValue: Bool? {
            switch self {
            case .backend: nil
            case .forceActive: true
            case .forceInactive: false
            }
        }

        init(overrideValue: Bool?) {
            switch overrideValue {
            case nil: self = .backend
            case true?: self = .forceActive
            case false?: self = .forceInactive
            }
        }
    }

    @Published private(set) var appliedMode: Mode
    @Published private(set) var callbackWired: Bool
    /// The persisted switch.
    @Published private(set) var isEnabled: Bool
    /// Whether profile taps open the host's Client profile right now: the flag forced on and the callback wired.
    @Published private(set) var isActive: Bool

    private let manager: UnifiedProfileManager
    private var storage = [AnyCancellable]()

    init(manager: UnifiedProfileManager? = nil) {
        let manager = manager ?? .instance
        self.manager = manager
        appliedMode = Mode(overrideValue: manager.state.exposeClientUserIdOverride)
        callbackWired = manager.state.profileCallbackWired
        isEnabled = manager.isEnabled
        isActive = manager.state.isSwitchOn
        manager.$state
            .sink { [unowned self] state in
                appliedMode = Mode(overrideValue: state.exposeClientUserIdOverride)
                callbackWired = state.profileCallbackWired
                isActive = state.isSwitchOn
                isEnabled = manager.isEnabled
            }
            .store(in: &storage)
    }

    /// The switch: forces the flag on and wires the callback, or clears the override and unwires it.
    func setEnabled(_ isOn: Bool) {
        manager.setEnabled(isOn)
        isEnabled = manager.isEnabled
    }

    /// Moves the community flag alone, until the SDK restarts.
    func apply(_ mode: Mode) {
        manager.setExposeClientUserIdOverride(mode.overrideValue)
    }

    /// The switch's subtitle: the current effective behavior, as on Android.
    static func effectLine(active: Bool) -> String {
        active ? "Profile taps open Client profile" : "Profile taps open native profiles"
    }
}
