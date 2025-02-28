//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection

extension Injected {
    static let validators = Injector.InjectedIdentifier<Validators>()
}

public class Validators: InjectableObject {
    public static let injectedIdentifier = Injected.validators

    public let currentUserProfile: Validators.CurrentUserProfile
    public let picture: Validators.Picture
    public let comment: Validators.Comment

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>) {
        picture = Picture()
        comment = Comment(pictureValidator: picture)
        currentUserProfile = CurrentUserProfile(pictureValidator: picture, appManagedFields: appManagedFields)
    }
}
