//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockTrackingService: TrackingService {
    /// Fifo of the responses to `track`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var trackResponses = [Com_Octopuscommunity_TrackResponse]()

    init() { }

    func track(events: [Com_Octopuscommunity_TrackRequest.Event], authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_TrackResponse {
        guard let response = trackResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextTrack must be called before"))
        }
        return response
    }
}

extension MockTrackingService {
    func injectNextTrack(_ response: Com_Octopuscommunity_TrackResponse) {
        trackResponses.insert(response, at: 0)
    }
}
