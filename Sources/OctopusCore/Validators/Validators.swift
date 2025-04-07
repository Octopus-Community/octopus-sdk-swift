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
    public let poll: Validators.Poll
    public let post: Validators.Post
    public let comment: Validators.Comment
    public let reply: Validators.Reply

    init(appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>) {
        picture = Picture()
        poll = Poll()
        post = Post(pictureValidator: picture, pollValidator: poll)
        comment = Comment(pictureValidator: picture)
        reply = Reply(pictureValidator: picture)
        currentUserProfile = CurrentUserProfile(pictureValidator: picture, appManagedFields: appManagedFields)
    }
}
