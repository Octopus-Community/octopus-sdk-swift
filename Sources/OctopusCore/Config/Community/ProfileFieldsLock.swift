//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Per-field editability status of a profile field, driven by the community configuration (OCT-1487).
///
/// `disabled` is only meaningful for the bio (the field disappears entirely); `nickname` and `avatar`
/// can only be `editable` or `readOnly`.
public enum ProfileFieldLockState: Equatable, Sendable, Hashable {
    /// Default behaviour: the field is displayed and modifiable.
    case editable
    /// The value is displayed but no longer modifiable (edit stays inside Octopus, no redirect).
    case readOnly
    /// The field disappears entirely (bio only).
    case disabled
}

/// Per-field profile lock for the current community.
public struct ProfileFieldsLock: Equatable, Sendable, Hashable {
    public let nickname: ProfileFieldLockState
    public let avatar: ProfileFieldLockState
    public let bio: ProfileFieldLockState

    public init(nickname: ProfileFieldLockState, avatar: ProfileFieldLockState, bio: ProfileFieldLockState) {
        self.nickname = nickname
        self.avatar = avatar
        self.bio = bio
    }

    /// Default when the community sets no per-field lock: every field editable (today's behaviour).
    public static let allEditable = ProfileFieldsLock(nickname: .editable, avatar: .editable, bio: .editable)
}

extension ProfileFieldLockState {
    /// nickname & avatar — proto `FieldLock`. Unknown values default to `.editable` (safe no-op).
    init(from fieldLock: Com_Octopuscommunity_FieldLock) {
        switch fieldLock {
        case .editable: self = .editable
        case .readOnly: self = .readOnly
        case .UNRECOGNIZED: self = .editable
        }
    }

    /// bio — proto `BioFieldLock`, which additionally carries `hidden` (mapped to `.disabled`).
    /// Unknown values default to `.editable` (safe no-op).
    init(from bioFieldLock: Com_Octopuscommunity_BioFieldLock) {
        switch bioFieldLock {
        case .editable: self = .editable
        case .readOnly: self = .readOnly
        case .hidden: self = .disabled
        case .UNRECOGNIZED: self = .editable
        }
    }
}

extension ProfileFieldsLock {
    init(from proto: Com_Octopuscommunity_ProfileFieldsLock) {
        nickname = ProfileFieldLockState(from: proto.nickname)
        avatar = ProfileFieldLockState(from: proto.avatar)
        bio = ProfileFieldLockState(from: proto.bio)
    }

    init(from entity: CommunityConfigEntity) {
        nickname = ProfileFieldLockState(storageValue: entity.nicknameLock)
        avatar = ProfileFieldLockState(storageValue: entity.avatarLock)
        bio = ProfileFieldLockState(storageValue: entity.bioLock)
    }
}

extension ProfileFieldLockState {
    /// Stable CoreData raw value. `0` (default for new/migrated rows) ⇒ `.editable` ⇒ no-op.
    var storageValue: Int16 {
        switch self {
        case .editable: 0
        case .readOnly: 1
        case .disabled: 2
        }
    }

    init(storageValue: Int16) {
        switch storageValue {
        case 1: self = .readOnly
        case 2: self = .disabled
        default: self = .editable
        }
    }
}
