//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GRPC

public enum AuthenticationMethod {
    case notAuthenticated
    case authenticated(token: String, authFailure: () -> Void)
}
