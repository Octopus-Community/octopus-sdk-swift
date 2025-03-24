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

        public enum BirthDateError: Error {
            case tooYoung
        }

        public let minNicknameLength = 3
        public let maxNicknameLength = 20

        public let maxBioLength = 200

        public let minAge = 16

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

        public func validate(picture: UIImage) -> Picture.ValidationResult {
            guard !appManagedFields.contains(.picture) else { return .valid }
            return pictureValidator.validate(picture)
        }

        public func validate(nickname: String) -> Result<Void, NicknameError> {
            guard !appManagedFields.contains(.nickname) else { return .success(Void()) }
            guard nickname.count >= minNicknameLength else { return .failure(.tooShort) }
            guard nickname.count <= maxNicknameLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public func validate(bio: String?) -> Result<Void, BioError> {
            guard !appManagedFields.contains(.bio) else { return .success(Void()) }
            guard let bio else { return .success(Void()) }
            guard bio.count <= maxBioLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public func validate(birthDate: Date) -> Result<Void, BirthDateError> {
            let calendar = Calendar.current
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
            guard let age = ageComponents.year, age >= minAge else { return .failure(.tooYoung) }
            return .success(Void())
        }

        public func validate(profile: EditableProfile) -> Bool {
            // Note that we can't check picture because we only have the data here
            if case let .updated(nickname) = profile.nickname,
               case .failure = validate(nickname: nickname) { return false }
            if case let .updated(bio) = profile.bio,
               case .failure = validate(bio: bio) { return false }
            return true
        }
    }
}
