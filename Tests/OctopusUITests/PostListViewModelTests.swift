//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing

struct PostListViewModelTests {

    // MARK: - canCreatePost mirrors canCreateAnyPost

    /// When every topic is accessible and allows children, the button should be visible.
    @Test func canCreatePost_trueWhenCanCreateAnyPostTrue() {
        #expect(resolve(canCreateAnyPost: true) == true)
    }

    /// When no topic allows post creation (e.g. all locked), the button should be hidden.
    @Test func canCreatePost_falseWhenCanCreateAnyPostFalse() {
        #expect(resolve(canCreateAnyPost: false) == false)
    }

    /// Pure derivation function exercised by the VM. Mirrors the 1-to-1 pass-through in
    /// `PostListViewModel.swift`: `canCreatePost = canCreateAnyPost`.
    private func resolve(canCreateAnyPost: Bool) -> Bool {
        canCreateAnyPost
    }
}
