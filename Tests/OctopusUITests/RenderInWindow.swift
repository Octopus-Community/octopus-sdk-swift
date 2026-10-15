//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
import UIKit

/// Puts the view in a visible window, where SwiftUI evaluates its body, until `condition` is met, then runs `next`
/// while the view is still displayed.
@MainActor
func renderInWindow<V: View>(_ view: V, until condition: () -> Bool,
                             andThen next: @MainActor () async throws -> Void = {}) async throws {
    // The test host runs without scenes, so the window is attached to the screen directly.
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = UIHostingController(rootView: view)
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    try await waitUntil(condition)
    try await next()
}

/// Waits, letting the main run loop turn, until `condition` is met, and records an issue after 5 seconds.
@MainActor
func waitUntil(_ condition: () -> Bool) async throws {
    // Plain nanoseconds rather than `Clock` / `Duration`, which need iOS 16 and the package targets iOS 13.
    let timeout: TimeInterval = 5
    let step: TimeInterval = 0.02
    var elapsed: TimeInterval = 0
    while !condition() {
        guard elapsed < timeout else {
            Issue.record("The view did not render or update in time")
            return
        }
        try await Task.sleep(nanoseconds: UInt64(step * 1_000_000_000))
        elapsed += step
    }
}
