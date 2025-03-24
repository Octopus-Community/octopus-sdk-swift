//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels
import GRPC

class MockMagicLinkStreamService: MagicLinkStreamService {
    /// Continuation in order to stream responses
    private var subscribeContinuation: AsyncStream<Com_Octopuscommunity_IsAuthenticatedResponse>.Continuation?

    func subscribe(magicLinkId: String,
                   email: String) -> any AsyncSequenceOf<Com_Octopuscommunity_IsAuthenticatedResponse> {
        let (stream, continuation) = AsyncStream<Com_Octopuscommunity_IsAuthenticatedResponse>.makeStream()
        subscribeContinuation = continuation
        return stream
    }
}

extension MockMagicLinkStreamService {
    public func streamSubscribeResponse(_ response: Com_Octopuscommunity_IsAuthenticatedResponse) throws {
        guard let subscribeContinuation else {
            throw MockError("Subscription has not been done yet")
        }
        subscribeContinuation.yield(response)
    }
}
