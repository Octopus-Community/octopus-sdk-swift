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
    public let picture: Validators.Picture
    public let post: Validators.Post
    public let comment: Validators.Comment

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>) {
        picture = Picture()
        post = Post(pictureValidator: picture)
        comment = Comment(pictureValidator: picture)
        currentUserProfile = CurrentUserProfile(pictureValidator: picture, appManagedFields: appManagedFields)
    }
}
