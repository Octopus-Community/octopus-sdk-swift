//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockMagicLinkService: MagicLinkService {
    /// Fifo of the responses to `generateLink`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var generateLinkResponses = [Com_Octopuscommunity_GenerateLinkResponse]()
    /// Fifo of the responses to `getJwt`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getJwtResponses = [Com_Octopuscommunity_IsAuthenticatedResponse]()


    func generateLink(email: String, deepLink: String?) async throws(RemoteClientError) -> Com_Octopuscommunity_GenerateLinkResponse {
        guard let generateLinkResponse = generateLinkResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGenerateLinkResponse must be called before"))
        }
        return generateLinkResponse
    }
    
    func getJwt(magicLinkId: String, email: String) async throws(RemoteClientError) -> Com_Octopuscommunity_IsAuthenticatedResponse {
        guard let getJwtResponse = getJwtResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetJwtResponse must be called before"))
        }
        return getJwtResponse
    }
}

extension MockMagicLinkService {
    func injectNextGenerateLinkResponse(_ response: Com_Octopuscommunity_GenerateLinkResponse) {
        generateLinkResponses.insert(response, at: 0)
    }

    func injectNextGetJwtResponse(_ response: Com_Octopuscommunity_IsAuthenticatedResponse) {
        getJwtResponses.insert(response, at: 0)
    }
}
