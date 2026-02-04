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

public protocol TrackingService {
    func track(
        events: [Com_Octopuscommunity_TrackRequest.Event],
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_TrackResponse
}

class TrackingServiceClient: ServiceClient, TrackingService {
    private let client: Com_Octopuscommunity_TrackingServiceAsyncClient


    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_TrackingServiceAsyncClient(
            channel: unaryChannel, interceptors: TrackingServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier)
    }

    func track(events: [Com_Octopuscommunity_TrackRequest.Event], authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_TrackResponse {
        let request = Com_Octopuscommunity_TrackRequest.with {
            $0.events = events
        }
        return try await callRemote(authenticationMethod) {
            try await client.track(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
