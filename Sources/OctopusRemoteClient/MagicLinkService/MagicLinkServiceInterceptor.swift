//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels

final class MagicLinkServiceInterceptor: Com_Octopuscommunity_MagicLinkServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    func makeGenerateLinkInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GenerateLinkRequest, Com_Octopuscommunity_GenerateLinkResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeConfirmLinkInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_ConfirmLinkRequest, Com_Octopuscommunity_ConfirmLinkResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetJWTInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_IsAuthenticatedRequest, Com_Octopuscommunity_IsAuthenticatedResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
