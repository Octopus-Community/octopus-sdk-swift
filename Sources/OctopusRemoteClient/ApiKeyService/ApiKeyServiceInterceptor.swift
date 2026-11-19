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

final class ApiKeyServiceInterceptor: Com_Octopuscommunity_ApiKeyServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    // Without `CommunityClosedInterceptor`: the config is the check a closure refusal asks for. Its own refusal
    // reported that way would start another check, whose refusal would start another one, past the bounded retries.
    func makeGetConfigInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_Empty, OctopusGrpcModels.Com_Octopuscommunity_GetConfigResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
