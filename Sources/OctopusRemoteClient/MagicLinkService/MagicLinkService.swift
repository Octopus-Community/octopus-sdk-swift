//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels
import Logging

public protocol MagicLinkService {
    func generateLink(email: String, deepLink: String?) async throws(RemoteClientError) -> Com_Octopuscommunity_GenerateLinkResponse
    func getJwt(magicLinkId: String, email: String) async throws(RemoteClientError) -> Com_Octopuscommunity_IsAuthenticatedResponse
}

class MagicLinkServiceClient: ServiceClient, MagicLinkService {
    private let client: Com_Octopuscommunity_MagicLinkServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_MagicLinkServiceAsyncClient(
            channel: unaryChannel,
            interceptors: MagicLinkServiceInterceptor(updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion)
    }

    public func generateLink(email: String, deepLink: String?) async throws(RemoteClientError) -> Com_Octopuscommunity_GenerateLinkResponse {
        let request = Com_Octopuscommunity_GenerateLinkRequest.with {
            $0.email = email
            if let deepLink {
                $0.deeplink = deepLink
            }
        }

        return try await callRemote(.notAuthenticated) {
            try await client.generateLink(request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }

    public func getJwt(magicLinkId: String, email: String) async throws(RemoteClientError) -> Com_Octopuscommunity_IsAuthenticatedResponse {
        let request = Com_Octopuscommunity_IsAuthenticatedRequest.with {
            $0.magicLinkID = magicLinkId
            $0.email = email
        }

        return try await callRemote(.notAuthenticated) {
            try await client.getJWT(request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }
}
