//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class OctopusProfileScreenViewModel: ObservableObject {

    /// Resolution state of `clientUserId` into an Octopus profile id. Only meaningful in other-user mode
    /// (`clientUserId != nil`); the dedicated lookup returns at most one profile, so there is no 0/1/N
    /// ambiguity to model here (unlike a search).
    enum ClientUserIdResolution {
        case resolving
        case resolved(profileId: String)
        case notFound
    }

    @Published private(set) var mainFlowPath = MainFlowPath()

    /// Whether there is any current session at all (guest or full user) to show a profile for. Only
    /// meaningful in self mode (`clientUserId == nil`) — a guest has a real profile so it is not gated on
    /// here, only the fully-not-connected case is. Starts optimistic (`true`) so we do not flash the
    /// unavailable state while the persisted session is still loading.
    @Published private(set) var isConnected = true

    /// Only meaningful in other-user mode (`clientUserId != nil`).
    @Published private(set) var resolution: ClientUserIdResolution = .resolving

    let octopus: OctopusSDK
    let clientUserId: String?

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, clientUserId: String?) {
        self.octopus = octopus
        self.clientUserId = clientUserId

        if let clientUserId {
            // Kick off the resolution from init (rather than a SwiftUI `.task` view modifier, which
            // requires iOS 15+ while this SDK targets iOS 13+) — same convention as
            // ProfileSummaryViewModel's initial `fetchProfile`.
            Task {
                await resolveClientUserId(clientUserId)
            }
        } else {
            octopus.core.connectionRepository.connectionStatePublisher
                .map { state in
                    if case .notConnected = state { return false } else { return true }
                }
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] in self?.isConnected = $0 }
                .store(in: &storage)
        }
    }

    private func resolveClientUserId(_ clientUserId: String) async {
        resolution = .resolving
        do {
            // Reuse the existing Unified Profile lookup (`fetchProfile(byClientUserId:)`), which resolves
            // the clientUserId, upserts the profile into the local cache and returns it. An unknown
            // clientUserId — or a community that does not expose client user ids — resolves to `nil`.
            if let profile = try await octopus.core.profileRepository.fetchProfile(byClientUserId: clientUserId) {
                resolution = .resolved(profileId: profile.id)
            } else {
                resolution = .notFound
            }
        } catch {
            // FAILED_PRECONDITION (community does not expose client user ids) and network failures are
            // surfaced the same way as not-found: a clean "not found" state (see OctopusProfileScreen).
            resolution = .notFound
        }
    }
}
