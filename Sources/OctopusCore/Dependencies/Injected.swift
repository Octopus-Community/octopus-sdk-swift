//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection
import RemoteClient

/// Namespace for injected objects
enum Injected {
    static let remoteClient = Injector.InjectedIdentifier<RemoteClient>()
}

extension GrpcClient: InjectableObject {
    public static let injectedIdentifier = Injected.remoteClient
}
