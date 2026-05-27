//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Per-object permissions for the current user, derived from the backend's `RequesterCtx`.
///
/// Defaults to fully open (`canAccess = true`, `canCreateChildren = true`) when the proto
/// field is absent — preserves backward-compatible behavior for groups without entitlement
/// requirements (PRD Rule 10).
///
/// `public` so cross-module consumers within this Swift package (`OctopusUI`, `Octopus`) can
/// read it. The host-app-facing surface is ``OctopusGroup/canAccess`` (a flat `Bool`).
public struct UserPermissions: Equatable, Hashable, Sendable {
    public let canAccess: Bool
    public let canCreateChildren: Bool

    public static let `default` = UserPermissions(canAccess: true, canCreateChildren: true)

    public init(canAccess: Bool, canCreateChildren: Bool) {
        self.canAccess = canAccess
        self.canCreateChildren = canCreateChildren
    }

    /// Builds a `UserPermissions` from optional booleans, defaulting `nil` to `true` (open).
    /// Used at the storage / proto-mapping boundaries where fields may be absent.
    public init(canAccess: Bool?, canCreateChildren: Bool?) {
        self.canAccess = canAccess ?? true
        self.canCreateChildren = canCreateChildren ?? true
    }

    init(from ctx: Com_Octopuscommunity_RequesterCtx?) {
        let access = ctx.flatMap { $0.hasCanAccess ? $0.canAccess : nil }
        let create = ctx.flatMap { $0.hasCanCreateChildren ? $0.canCreateChildren : nil }
        self.init(canAccess: access, canCreateChildren: create)
    }
}
