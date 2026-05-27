//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct UserPermissionsMappingTests {

    @Test func defaultIsFullyOpen() {
        let permissions = UserPermissions.default
        #expect(permissions.canAccess == true)
        #expect(permissions.canCreateChildren == true)
    }

    @Test func nilContextDefaultsToOpen() {
        let permissions = UserPermissions(from: nil)
        #expect(permissions.canAccess == true)
        #expect(permissions.canCreateChildren == true)
    }

    @Test func absentFieldsDefaultToOpen() {
        let ctx = Com_Octopuscommunity_RequesterCtx()
        let permissions = UserPermissions(from: ctx)
        #expect(permissions.canAccess == true)
        #expect(permissions.canCreateChildren == true)
    }

    @Test func presentTrueValuesPassThrough() {
        var ctx = Com_Octopuscommunity_RequesterCtx()
        ctx.canAccess = true
        ctx.canCreateChildren = true
        let permissions = UserPermissions(from: ctx)
        #expect(permissions.canAccess == true)
        #expect(permissions.canCreateChildren == true)
    }

    @Test func presentFalseValuesPassThrough() {
        var ctx = Com_Octopuscommunity_RequesterCtx()
        ctx.canAccess = false
        ctx.canCreateChildren = false
        let permissions = UserPermissions(from: ctx)
        #expect(permissions.canAccess == false)
        #expect(permissions.canCreateChildren == false)
    }

    @Test func canAccessTrueButCanCreateChildrenFalse() {
        var ctx = Com_Octopuscommunity_RequesterCtx()
        ctx.canAccess = true
        ctx.canCreateChildren = false
        let permissions = UserPermissions(from: ctx)
        #expect(permissions.canAccess == true)
        #expect(permissions.canCreateChildren == false)
    }
}
