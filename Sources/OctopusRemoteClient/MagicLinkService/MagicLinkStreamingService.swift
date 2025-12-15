//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels
import Logging

public protocol MagicLinkStreamService {
    func subscribe(magicLinkId: String,
                   email: String) -> any AsyncSequenceOf<Com_Octopuscommunity_IsAuthenticatedResponse>
}

class MagicLinkStreamingServiceClient: ServiceClient, MagicLinkStreamService {
    private let client: Com_Octopuscommunity_MagicLinkStreamServiceAsyncClient

    init(streamingChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String) {
        client = Com_Octopuscommunity_MagicLinkStreamServiceAsyncClient(channel: streamingChannel)
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId)
    }

    public func subscribe(magicLinkId: String, email: String) -> any AsyncSequenceOf<Com_Octopuscommunity_IsAuthenticatedResponse> {
        let request = Com_Octopuscommunity_IsAuthenticatedRequest.with {
            $0.magicLinkID = magicLinkId
            $0.email = email
        }

        return client.subscribe(request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
    }
}

extension GRPCAsyncResponseStream: AsyncSequenceOf { }
