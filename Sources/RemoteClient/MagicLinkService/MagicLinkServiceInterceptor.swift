//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import GrpcModels

final class MagicLinkServiceInterceptor: Com_Octopuscommunity_MagicLinkServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let updateTokenBlock: (String) -> Void

    init(updateTokenBlock: @escaping (String) -> Void) {
        self.updateTokenBlock = updateTokenBlock
    }

    func makeGenerateLinkInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GenerateLinkRequest, Com_Octopuscommunity_GenerateLinkResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeConfirmLinkInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_ConfirmLinkRequest, Com_Octopuscommunity_ConfirmLinkResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetJWTInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_IsAuthenticatedRequest, Com_Octopuscommunity_IsAuthenticatedResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
