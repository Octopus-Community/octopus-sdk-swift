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
    /// - Parameter bypassingCallsGate: whether the call is sent even though calls are blocked, to learn whether a
    ///   closed community has reopened.
    func getConfig(bypassingCallsGate: Bool) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetConfigResponse
}

public extension ApiKeyService {
    func getConfig() async throws(RemoteClientError) -> Com_Octopuscommunity_GetConfigResponse {
        try await getConfig(bypassingCallsGate: false)
    }
}

class ApiKeyServiceClient: ServiceClient, ApiKeyService {
    private let client: Com_Octopuscommunity_ApiKeyServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         sdkIdentity: @escaping @Sendable () -> SdkIdentity,
         callsGate: CallsGate,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_ApiKeyServiceAsyncClient(
            channel: unaryChannel, interceptors: ApiKeyServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier,
                   sdkIdentity: sdkIdentity, callsGate: callsGate)
    }

    func getConfig(bypassingCallsGate: Bool) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetConfigResponse {
        let request = Com_Octopuscommunity_Empty()

        return try await callRemote(.notAuthenticated, bypassingCallsGate: bypassingCallsGate) {
            try await client.getConfig(
                request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }
}
