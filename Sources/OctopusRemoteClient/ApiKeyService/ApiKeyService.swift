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

public protocol ApiKeyService {
    func getConfig() async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetConfigResponse
}

class ApiKeyServiceClient: ServiceClient, ApiKeyService {
    private let client: Com_Octopuscommunity_ApiKeyServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_ApiKeyServiceAsyncClient(
            channel: unaryChannel, interceptors: ApiKeyServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier)
    }

    func getConfig() async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetConfigResponse {
        let request = Com_Octopuscommunity_Empty()

        return try await callRemote(.notAuthenticated) {
            try await client.getConfig(
                request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }
}
