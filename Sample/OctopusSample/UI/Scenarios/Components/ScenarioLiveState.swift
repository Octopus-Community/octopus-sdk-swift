//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// The values the SDK publishes that the scenarios show live. A community switch rebuilds the SDK, so the
/// subscriptions follow the new instance on `.apiKeyChanged`.
@MainActor
final class ScenarioLiveState: ObservableObject {
    static let instance = ScenarioLiveState()

    @Published private(set) var profile: OctopusProfile?
    @Published private(set) var groups: [OctopusGroup] = []
    @Published private(set) var notSeenNotificationsCount = 0
    @Published private(set) var hasAccessToCommunity = false
    /// What the Events scenario shows of the tracking log: its size and newest entry, not a copy of the log.
    @Published private(set) var eventCount = 0
    @Published private(set) var lastEvent: OctopusEvent?

    private var sdkStorage = [AnyCancellable]()
    private var storage = [AnyCancellable]()

    private init() {
        NotificationCenter.default.publisher(for: .apiKeyChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.bind() }
            .store(in: &storage)
        TrackingManager.instance.$events
            .map { (count: $0.count, last: $0.last) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.eventCount = $0.count
                self?.lastEvent = $0.last
            }
            .store(in: &storage)
        bind()
    }

    /// "Connected (Guest)", "Connected (<nickname>)" or "NotConnected", worded as on Android.
    var connectionState: String {
        guard let profile else { return "NotConnected" }
        if profile.isGuest { return "Connected (Guest)" }
        let name = AppUserManager.instance.appUser?.nickname ?? profile.clientUserId ?? "member"
        return "Connected (\(name))"
    }

    var isUserConnected: Bool { profile.map { !$0.isGuest } ?? false }

    private func bind() {
        sdkStorage = []
        guard let octopus = OctopusSDKProvider.instance.octopus else { return }
        octopus.$profile.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.profile = $0 }.store(in: &sdkStorage)
        octopus.$groups.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.groups = $0 }.store(in: &sdkStorage)
        octopus.$notSeenNotificationsCount.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.notSeenNotificationsCount = $0 }.store(in: &sdkStorage)
        octopus.$hasAccessToCommunity.receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.hasAccessToCommunity = $0 }.store(in: &sdkStorage)
    }
}

/// A scenario failure whose text is what the Result zone shows.
struct ScenarioFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}
