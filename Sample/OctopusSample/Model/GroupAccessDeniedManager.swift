//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// Singleton that bridges the SDK's `groupAccessDeniedCallback` to a published property
/// that views can observe. Exposes state through `@Published` so SwiftUI views can react via `.onReceive(...)`.
class GroupAccessDeniedManager: ObservableObject {
    static let instance = GroupAccessDeniedManager()

    /// The id of the most recently denied group, or `nil` once the host UI has handled it.
    /// Reset to `nil` after presentation to allow subsequent denials to fire the observer
    /// again — the published value transitions act as events.
    @Published var deniedGroupId: String?

    /// How the Scenarios screen asked the callback to behave, `nil` when it follows Settings › Host app integration.
    enum ScenarioMode: Equatable {
        /// Counts each call in `scenarioFireCount` and never navigates.
        case counting
        /// A block that does nothing: the setter's parameter cannot be `nil`.
        case noop
    }

    @Published private(set) var scenarioMode: ScenarioMode?
    /// Calls received while `scenarioMode` is `.counting`.
    @Published private(set) var scenarioFireCount = 0

    private weak var octopus: OctopusSDK?
    private var storage = [AnyCancellable]()

    private init() {
        // Settings › Host app integration can switch the callback off: re-wire the live instance at once.
        HostIntegrationStore.instance.$isGroupAccessDeniedWired
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] in self?.applyWiring(isWired: $0) }
            .store(in: &storage)
    }

    /// Function called when the Octopus SDK is created.
    func set(octopus: OctopusSDK) {
        self.octopus = octopus
        applyWiring(isWired: HostIntegrationStore.instance.isGroupAccessDeniedWired)
    }

    /// Registers the scenario's own callback, or hands control back to the Settings wiring with `nil`.
    func setScenarioMode(_ mode: ScenarioMode?) {
        scenarioMode = mode
        applyWiring(isWired: HostIntegrationStore.instance.isGroupAccessDeniedWired)
    }

    private func applyWiring(isWired: Bool) {
        switch scenarioMode {
        case .counting?:
            octopus?.set(groupAccessDeniedCallback: { [weak self] _ in
                DispatchQueue.main.async { self?.scenarioFireCount += 1 }
            })
            return
        case .noop?:
            octopus?.set(groupAccessDeniedCallback: { _ in })
            return
        case nil:
            break
        }
        // The setter takes a non-optional block, so "not handled by the app" is a block that does nothing.
        octopus?.set(groupAccessDeniedCallback: isWired ? { [weak self] groupId in
            /// Block invoked by the SDK when the user taps a visible-but-not-accessible group
            /// (in the Groups list, the create-post picker, the locked group detail screen,
            /// etc.). The host app decides what to do with the `groupId`. In this sample we
            /// surface a screen that lets the tester adjust their entitlements and retry.
            self?.deniedGroupId = groupId
        } : { _ in })
    }
}
