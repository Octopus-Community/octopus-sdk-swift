//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import NIOHPACK

enum RefreshingTokenError: Error {
    case userIdNotMatching
}

class RefreshingTokenInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {

    private let getUserId: () -> String?
    private let updateTokenBlock: (String) -> Void

    private let userIdWhenRequestSent: String?

    init(getUserId: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserId = getUserId
        self.updateTokenBlock = updateTokenBlock
        userIdWhenRequestSent = getUserId()
    }

    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
        guard userIdWhenRequestSent == getUserId() else {
            context.errorCaught(RefreshingTokenError.userIdNotMatching)
            return
        }

        switch part {
        case let .metadata(headers):
            if let newJwt = headers.first(name: "access-token") {
                updateTokenBlock(newJwt)
            }
        default:
            break
        }

        context.receive(part)
    }
}
