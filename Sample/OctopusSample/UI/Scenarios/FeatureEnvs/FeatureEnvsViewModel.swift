//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// Drives the Feature Environments scenario: loads the directory, applies a selection, clears it.
@MainActor
final class FeatureEnvsViewModel: ObservableObject {
    @Published private(set) var envs: [FeatureEnv] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isApplying = false
    @Published private(set) var currentFeatureEnv: FeatureEnvSelection?
    /// Selection dropped at launch (expired or unusable host), so the screen can explain the fallback.
    @Published private(set) var droppedAtLaunch: FeatureEnvSelection?

    private var storage = [AnyCancellable]()
    /// Held so `.onAppear`, `.refreshable` and the nav-bar button coalesce into one in-flight fetch
    /// instead of three, and so leaving the screen cancels it.
    private var loadTask: Task<Void, Never>?

    init() {
        let provider = OctopusSDKProvider.instance
        currentFeatureEnv = provider.currentFeatureEnv
        droppedAtLaunch = provider.featureEnvDroppedAtLaunch
        provider.$currentFeatureEnv
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.currentFeatureEnv = $0 }
            .store(in: &storage)
        provider.$featureEnvDroppedAtLaunch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.droppedAtLaunch = $0 }
            .store(in: &storage)
    }

    func load() async {
        // A second trigger joins the running fetch rather than starting another one.
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { await performLoad() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// Called when the screen goes away: nothing is waiting for the answer any more.
    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func performLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            envs = try await FeatureEnvsDirectory.fetch()
        } catch {
            // Cancellation is not a directory failure — the developer just left the screen.
            if !Task.isCancelled { errorMessage = error.userMessage }
        }
        isLoading = false
    }

    func select(env: FeatureEnv, community: FeatureEnv.Community) async {
        await apply(FeatureEnvSelection(env: env, community: community))
    }

    /// Called when the screen goes away: the notice about the env dropped at launch has been read.
    func acknowledgeDroppedNotice() {
        OctopusSDKProvider.instance.acknowledgeFeatureEnvDropped()
    }

    func clearSelection() async {
        await apply(nil)
    }

    private func apply(_ selection: FeatureEnvSelection?) async {
        // A second tap on this screen is a no-op rather than an error: `.disabled(isApplying)` on the rows
        // only takes effect on the next render pass, so the taps landing before it still arrive here.
        // Overlapping switches are refused by `OctopusSDKProvider`, which is where that rule lives — but it
        // reports a refusal as an error, which is the right answer for a switch started elsewhere and not
        // for a double tap on the row the developer has just used.
        guard !isApplying else { return }
        isApplying = true
        errorMessage = nil
        do {
            try await OctopusSDKProvider.instance.apply(featureEnv: selection)
        } catch {
            errorMessage = "Could not switch: \(error.localizedDescription)"
        }
        isApplying = false
    }
}
