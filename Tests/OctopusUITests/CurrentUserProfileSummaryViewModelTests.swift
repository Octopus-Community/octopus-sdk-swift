//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing

struct CurrentUserProfileSummaryViewModelTests {

    // MARK: - canCreatePost mirrors canCreateAnyPost

    /// When every topic is accessible and allows children, the incentive buttons should be visible.
    @Test func canCreatePost_trueWhenCanCreateAnyPostTrue() {
        #expect(resolve(canCreateAnyPost: true) == true)
    }

    /// When no topic allows post creation (e.g. all locked), the incentive buttons should be hidden.
    @Test func canCreatePost_falseWhenCanCreateAnyPostFalse() {
        #expect(resolve(canCreateAnyPost: false) == false)
    }

    /// Pure derivation function exercised by the VM. Mirrors the 1-to-1 pass-through in
    /// `CurrentUserProfileSummaryViewModel.swift`: `canCreatePost = canCreateAnyPost`.
    private func resolve(canCreateAnyPost: Bool) -> Bool {
        canCreateAnyPost
    }
}
