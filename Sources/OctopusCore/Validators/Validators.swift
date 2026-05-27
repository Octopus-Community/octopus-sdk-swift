//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

extension Injected {
    static let validators = Injector.InjectedIdentifier<Validators>()
}

public class Validators: InjectableObject {
    public static let injectedIdentifier = Injected.validators

    public let currentUserProfile: Validators.CurrentUserProfile

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>) {
        currentUserProfile = CurrentUserProfile(appManagedFields: appManagedFields)
    }
}
