//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockApiKeyService: ApiKeyService {
    /// Fifo of the responses to `getConfig`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    /// Locked: refreshes call `getConfig` from tasks, concurrently with each other and with the test injecting.
    private var getConfigResponses = [Com_Octopuscommunity_GetConfigResponse]()
    private let lock = NSLock()

    func getConfig() async throws(RemoteClientError) -> Com_Octopuscommunity_GetConfigResponse {
        guard let getConfigResponse = popNextGetConfigResponse() else {
            throw .unknown(MockError("Dev error, injectNextGetConfigResponse must be called before"))
        }
        return getConfigResponse
    }

    private func popNextGetConfigResponse() -> Com_Octopuscommunity_GetConfigResponse? {
        lock.lock()
        defer { lock.unlock() }
        return getConfigResponses.popLast()
    }
}

extension MockApiKeyService {
    func injectNextGetConfigResponse(_ response: Com_Octopuscommunity_GetConfigResponse) {
        lock.lock()
        defer { lock.unlock() }
        getConfigResponses.insert(response, at: 0)
    }
}
