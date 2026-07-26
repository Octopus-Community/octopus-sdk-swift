//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// View model of ClientProfileScreen.
///
/// Fetches the tapped member's ``OctopusCommunityData`` (Unified Profile, OCT-1374) so the host's
/// own profile stand-in can surface Octopus community stats à la carte, without rendering any
/// Octopus UI.
@MainActor
class ClientProfileViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(OctopusCommunityData?)
        case error(String)
    }

    let clientUserId: String

    @Published private(set) var state: State = .loading

    private let octopus: OctopusSDK? = OctopusSDKProvider.instance.octopus

    init(clientUserId: String) {
        self.clientUserId = clientUserId
    }

    func fetchCommunityData() async {
        guard let octopus else {
            state = .error("SDK not initialized.")
            return
        }
        state = .loading
        do {
            let communityData = try await octopus.fetchCommunityData(clientUserId: clientUserId)
            state = .loaded(communityData)
        } catch {
            // This sample surfaces the raw error for debugging (matching the Android sample). A real
            // app should map it to a user-friendly message rather than showing the description.
            state = .error(String(describing: error))
        }
    }
}
