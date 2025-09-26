//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit
import OctopusDependencyInjection

public extension Validators {
    class CurrentUserProfile {
        public enum NicknameError: Error {
            case tooShort
            case tooLong
        }

        public enum BioError: Error {
            case tooLong
        }

        public let minNicknameLength = 3
        public let maxNicknameLength = 20

        public let maxBioLength = 200

        public var pictureMinSize: CGFloat { pictureValidator.minSize }
        public var pictureMaxRatio: CGFloat { pictureValidator.maxRatio }
        public var pictureMaxRatioStr: String { pictureValidator.maxRatioStr }

        private let pictureValidator: Validators.Picture
        private let appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>

        public init(pictureValidator: Validators.Picture,
                    appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>) {
            self.pictureValidator = pictureValidator
            self.appManagedFields = appManagedFields
        }

        public func validate(picture: UIImage, isGuest: Bool) -> Picture.ValidationResult {
            guard !appManagedFields.contains(.picture) || isGuest else { return .valid }
            return pictureValidator.validate(picture)
        }

        public func validate(nickname: String, isGuest: Bool) -> Result<Void, NicknameError> {
            guard !appManagedFields.contains(.nickname) || isGuest else { return .success(Void()) }
            guard nickname.count >= minNicknameLength else { return .failure(.tooShort) }
            guard nickname.count <= maxNicknameLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public func validate(bio: String?, isGuest: Bool) -> Result<Void, BioError> {
            guard !appManagedFields.contains(.bio) || isGuest else { return .success(Void()) }
            guard let bio else { return .success(Void()) }
            guard bio.count <= maxBioLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public func validate(profile: EditableProfile, isGuest: Bool) -> Bool {
            // Note that we can't check picture because we only have the data here
            if case let .updated(nickname) = profile.nickname,
               case .failure = validate(nickname: nickname, isGuest: isGuest) { return false }
            if case let .updated(bio) = profile.bio,
               case .failure = validate(bio: bio, isGuest: isGuest) { return false }
            return true
        }
    }
}
