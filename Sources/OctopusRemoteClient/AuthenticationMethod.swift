//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif

public enum AuthenticationMethod {
    case notAuthenticated
    case authenticated(token: String, authFailure: () -> Void)
}
