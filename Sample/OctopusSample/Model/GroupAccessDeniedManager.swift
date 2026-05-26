//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// Singleton that bridges the SDK's `groupAccessDeniedCallback` to a published property
/// that views can observe. Exposes state through `@Published` so SwiftUI views can react via `.onReceive(...)`.
class GroupAccessDeniedManager: ObservableObject {
    static let instance = GroupAccessDeniedManager()

    /// The id of the most recently denied group, or `nil` once the host UI has handled it.
    /// Reset to `nil` after presentation to allow subsequent denials to fire the observer
    /// again — the published value transitions act as events.
    @Published var deniedGroupId: String?

    private init() { }

    /// Function called when the Octopus SDK is created.
    func set(octopus: OctopusSDK) {
        octopus.set(groupAccessDeniedCallback: { [weak self] groupId in
            /// Block invoked by the SDK when the user taps a visible-but-not-accessible group
            /// (in the Groups list, the create-post picker, the locked group detail screen,
            /// etc.). The host app decides what to do with the `groupId`. In this sample we
            /// surface a screen that lets the tester adjust their entitlements and retry.
            self?.deniedGroupId = groupId
        })
    }
}
