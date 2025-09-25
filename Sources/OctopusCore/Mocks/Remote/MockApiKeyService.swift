//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockApiKeyService: ApiKeyService {
    /// Fifo of the responses to `getConfig`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getConfigResponses = [Com_Octopuscommunity_GetConfigResponse]()

    func getConfig() async throws(RemoteClientError) -> Com_Octopuscommunity_GetConfigResponse {
        guard let getConfigResponse = getConfigResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetConfigResponse must be called before"))
        }
        return getConfigResponse
    }
}

extension MockApiKeyService {
    func injectNextGetConfigResponse(_ response: Com_Octopuscommunity_GetConfigResponse) {
        getConfigResponses.insert(response, at: 0)
    }
}
