//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import NIOHPACK

class RefreshingTokenInterceptor<Request, Response>: ClientInterceptor<Request, Response>, @unchecked Sendable {

    private let updateTokenBlock: (String) -> Void

    init(updateTokenBlock: @escaping (String) -> Void) {
        self.updateTokenBlock = updateTokenBlock
    }

    override func receive(
        _ part: GRPCClientResponsePart<Response>,
        context: ClientInterceptorContext<Request, Response>
    ) {
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
