//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusCore

struct LockedContentStateTests {

    @Test func unlockedWhenCanAccessAndCanCreateChildren() {
        let state = LockedContentState(
            permissions: UserPermissions(canAccess: true, canCreateChildren: true),
            isOwnContent: false)
        #expect(state == .unlocked)
    }

    @Test func unlockedRegardlessOfAuthorshipWhenAccessGranted() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: true)
        #expect(LockedContentState(permissions: permissions, isOwnContent: true) == .unlocked)
        #expect(LockedContentState(permissions: permissions, isOwnContent: false) == .unlocked)
    }

    @Test func composeLockedWhenCanAccessButNotCanCreateChildren() {
        let state = LockedContentState(
            permissions: UserPermissions(canAccess: true, canCreateChildren: false),
            isOwnContent: false)
        #expect(state == .composeLocked)
    }

    @Test func composeLockedRegardlessOfAuthorshipWhenAccessGrantedButCreationDenied() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: false)
        #expect(LockedContentState(permissions: permissions, isOwnContent: true) == .composeLocked)
        #expect(LockedContentState(permissions: permissions, isOwnContent: false) == .composeLocked)
    }

    @Test func lockedOwnContentWhenAccessDeniedAndOwnContent() {
        let state = LockedContentState(
            permissions: UserPermissions(canAccess: false, canCreateChildren: false),
            isOwnContent: true)
        #expect(state == .lockedOwnContent)
    }

    @Test func lockedOtherWhenAccessDeniedAndNotOwnContent() {
        let state = LockedContentState(
            permissions: UserPermissions(canAccess: false, canCreateChildren: false),
            isOwnContent: false)
        #expect(state == .lockedOther)
    }
}
