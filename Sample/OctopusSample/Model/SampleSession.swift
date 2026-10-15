//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// What the sample shows of the SDK session: whether there is one, a guest's or a real user's, and the
/// entitlements it carries. A plain value built from `OctopusProfile`, so the screens' logic is unit-tested
/// without a live SDK.
struct SampleSession: Equatable {
    /// No session at all: the SDK has not opened one yet, not even a guest one.
    static let none = SampleSession(hasProfile: false, isGuest: false, grantedEntitlements: [])

    let hasProfile: Bool
    let isGuest: Bool
    /// The entitlements the backend granted to this session.
    let grantedEntitlements: Set<String>

    /// A real SSO identity, as opposed to the guest session the SDK opens on its own.
    var isSignedIn: Bool { hasProfile && !isGuest }

    init(hasProfile: Bool, isGuest: Bool, grantedEntitlements: Set<String>) {
        self.hasProfile = hasProfile
        self.isGuest = isGuest
        self.grantedEntitlements = grantedEntitlements
    }

    init(profile: OctopusProfile?) {
        self.init(hasProfile: profile != nil, isGuest: profile?.isGuest ?? false,
                  grantedEntitlements: profile?.entitlements ?? [])
    }

    /// The session of the current SDK instance, followed across community switches, which rebuild the SDK.
    /// Empty until the SDK exists, so reading it never builds one.
    @MainActor
    static func current() -> AnyPublisher<SampleSession, Never> {
        NotificationCenter.default.publisher(for: .apiKeyChanged)
            .map { _ in () }
            .prepend(())
            .map { _ -> AnyPublisher<SampleSession, Never> in
                guard OctopusSDKProvider.isCreated, let octopus = OctopusSDKProvider.instance.octopus else {
                    return Just(.none).eraseToAnyPublisher()
                }
                return octopus.$profile.map(SampleSession.init(profile:)).eraseToAnyPublisher()
            }
            .switchToLatest()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
