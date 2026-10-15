//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// The last SDK call a scenario made, as the Result zone shows it.
struct ScenarioCall: Equatable {
    var isLoading = false
    /// The raw outcome, `nil` while the call runs.
    var result: String?
    var isError = false
    var durationMs: Int?
}

/// Runs the calls behind the scenario presets and keeps the last one per scenario, so the Result zone shows the
/// same outcome when the scenario is reopened, as on Android.
@MainActor
final class ScenarioRunner: ObservableObject {
    static let instance = ScenarioRunner()

    @Published private(set) var calls: [ScenarioID: ScenarioCall] = [:]

    /// Runs `operation` for `id`: the Result zone shows the skeleton until it returns, then the returned text, or
    /// the error's description as a failure.
    func run(_ id: ScenarioID, _ operation: @escaping @MainActor () async throws -> String) {
        guard calls[id]?.isLoading != true else { return }
        calls[id] = ScenarioCall(isLoading: true)
        let start = Date()
        Task { @MainActor in
            var call = ScenarioCall()
            do {
                call.result = try await operation()
            } catch {
                call.result = String(describing: error)
                call.isError = true
            }
            call.durationMs = Int(Date().timeIntervalSince(start) * 1000)
            calls[id] = call
        }
    }

    /// Records an outcome that needed no asynchronous call.
    func record(_ id: ScenarioID, result: String, isError: Bool = false) {
        calls[id] = ScenarioCall(result: result, isError: isError, durationMs: 0)
    }
}
