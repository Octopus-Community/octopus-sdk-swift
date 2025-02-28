//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import RemoteClient

public struct EditableProfile: Sendable {
    public enum FieldUpdate<T: Sendable>: Sendable {
        case notUpdated
        case updated(T)
    }

    public let nickname: FieldUpdate<String>
    public let bio: FieldUpdate<String?>
    public internal(set) var picture: FieldUpdate<Data?>

    public init(nickname: FieldUpdate<String> = .notUpdated,
                bio: FieldUpdate<String?> = .notUpdated,
                picture: FieldUpdate<Data?> = .notUpdated) {
        self.nickname = nickname
        self.bio = bio
        self.picture = picture
    }
}

/// Extension that adds translation to RemoteClient.FieldUpdate
extension EditableProfile.FieldUpdate {
    var backendValue: FieldUpdate<T> {
        switch self {
        case .notUpdated: return .notUpdated
        case .updated(let value): return .updated(value)
        }
    }

    func map<U>(_ transform: (T) throws -> U) rethrows -> EditableProfile.FieldUpdate<U> {
        switch self {
        case .notUpdated: return .notUpdated
        case .updated(let value): return .updated(try transform(value))
        }
    }
}
