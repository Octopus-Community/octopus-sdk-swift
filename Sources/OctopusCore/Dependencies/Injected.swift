//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import OctopusRemoteClient

/// Namespace for injected objects
enum Injected {
    static let remoteClient = Injector.InjectedIdentifier<OctopusRemoteClient>()
}

extension GrpcClient: InjectableObject {
    public static let injectedIdentifier = Injected.remoteClient
}
