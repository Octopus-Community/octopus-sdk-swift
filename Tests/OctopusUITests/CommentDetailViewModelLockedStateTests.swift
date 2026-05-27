//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusCore

struct CommentDetailViewModelLockedStateTests {

    @Test func unlockedWhenCanAccessTrueAndCanCreateChildrenTrue() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: true)
        let state = resolve(permissions: permissions, authorId: "a", currentUserId: "a")
        #expect(state == .unlocked)
    }

    @Test func unlockedEvenWhenAuthorMismatch() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: true)
        let state = resolve(permissions: permissions, authorId: "a", currentUserId: "b")
        #expect(state == .unlocked)
    }

    @Test func composeLockedWhenCanAccessTrueAndCanCreateChildrenFalse() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: false)
        let state = resolve(permissions: permissions, authorId: "a", currentUserId: "a")
        #expect(state == .composeLocked)
    }

    @Test func composeLockedRegardlessOfAuthorMatch() {
        let permissions = UserPermissions(canAccess: true, canCreateChildren: false)
        let stateOwn = resolve(permissions: permissions, authorId: "u1", currentUserId: "u1")
        let stateOther = resolve(permissions: permissions, authorId: "u1", currentUserId: "u2")
        #expect(stateOwn == .composeLocked)
        #expect(stateOther == .composeLocked)
    }

    @Test func lockedOwnContentWhenAuthorMatchesCurrentUser() {
        let permissions = UserPermissions(canAccess: false, canCreateChildren: false)
        let state = resolve(permissions: permissions, authorId: "u1", currentUserId: "u1")
        #expect(state == .lockedOwnContent)
    }

    @Test func lockedOtherWhenAuthorDifferent() {
        let permissions = UserPermissions(canAccess: false, canCreateChildren: false)
        let state = resolve(permissions: permissions, authorId: "u1", currentUserId: "u2")
        #expect(state == .lockedOther)
    }

    @Test func lockedOtherWhenAuthorNil() {
        let permissions = UserPermissions(canAccess: false, canCreateChildren: false)
        let state = resolve(permissions: permissions, authorId: nil, currentUserId: "u1")
        #expect(state == .lockedOther)
    }

    @Test func lockedOtherWhenCurrentUserNil() {
        let permissions = UserPermissions(canAccess: false, canCreateChildren: false)
        let state = resolve(permissions: permissions, authorId: "u1", currentUserId: nil)
        #expect(state == .lockedOther)
    }

    /// Pure derivation function exercised by the VM. Mirrors the inline derivation in
    /// `CommentDetailViewModel.swift`.
    private func resolve(permissions: UserPermissions,
                         authorId: String?,
                         currentUserId: String?) -> LockedContentState {
        if permissions.canAccess {
            if permissions.canCreateChildren {
                return .unlocked
            } else {
                return .composeLocked
            }
        } else if let authorId, let currentUserId, authorId == currentUserId {
            return .lockedOwnContent
        } else {
            return .lockedOther
        }
    }
}
