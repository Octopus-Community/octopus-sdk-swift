//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
struct CreatePostAttachmentRulesTests {
    private func rules(pictures: Bool = true, polls: Bool = true,
                       hasImage: Bool = false, hasPoll: Bool = false) -> CreatePostAttachmentRules {
        CreatePostAttachmentRules(picturesEnabled: pictures, pollsEnabled: polls,
                                  hasImage: hasImage, hasPoll: hasPoll)
    }

    // Swift Testing takes at most 2 argument collections, so the third dimension (pollsEnabled) is
    // folded into a single collection of labeled tuples covering all 8 combinations.
    @Test(arguments: [
        (pollsEnabled: false, hasImage: false, hasPoll: false),
        (pollsEnabled: false, hasImage: false, hasPoll: true),
        (pollsEnabled: false, hasImage: true, hasPoll: false),
        (pollsEnabled: false, hasImage: true, hasPoll: true),
        (pollsEnabled: true, hasImage: false, hasPoll: false),
        (pollsEnabled: true, hasImage: false, hasPoll: true),
        (pollsEnabled: true, hasImage: true, hasPoll: false),
        (pollsEnabled: true, hasImage: true, hasPoll: true)
    ])
    func pictureEntryFollowsTheCommunitySettingOnly(
        _ combination: (pollsEnabled: Bool, hasImage: Bool, hasPoll: Bool)
    ) {
        #expect(rules(pictures: true, polls: combination.pollsEnabled, hasImage: combination.hasImage,
                      hasPoll: combination.hasPoll).canAddPicture)
        #expect(!rules(pictures: false, polls: combination.pollsEnabled, hasImage: combination.hasImage,
                       hasPoll: combination.hasPoll).canAddPicture)
    }

    @Test(arguments: [false, true], [false, true])
    func pollEntryIsOfferedUntilAPollExists(picturesEnabled: Bool, hasImage: Bool) {
        #expect(rules(pictures: picturesEnabled, hasImage: hasImage, hasPoll: false).canAddPoll)
        #expect(!rules(pictures: picturesEnabled, hasImage: hasImage, hasPoll: true).canAddPoll)
    }

    /// Restates the spec's prefilled-image rule: at this level, a prefilled image is just `hasImage: true`.
    @Test func prefilledImageStillOffersAPoll() {
        #expect(rules(hasImage: true, hasPoll: false).canAddPoll)
    }

    @Test func pollEntryIsHiddenWhenPollsAreDisabled() {
        #expect(!rules(polls: false).canAddPoll)
    }

    @Test func actionBarIsHiddenOnlyWhenItHasNoEntry() {
        #expect(rules(pictures: true, polls: false, hasPoll: true).showsActionBar)
        #expect(rules(pictures: true, polls: true, hasPoll: true).showsActionBar)
        #expect(rules(pictures: false, polls: true, hasPoll: false).showsActionBar)
        #expect(!rules(pictures: false, polls: true, hasPoll: true).showsActionBar)
        #expect(!rules(pictures: false, polls: false).showsActionBar)
    }

    @Test func hasNoAttachmentOnlyWhenNeitherImageNorPoll() {
        #expect(rules().hasNoAttachment)
        #expect(!rules(hasImage: true).hasNoAttachment)
        #expect(!rules(hasPoll: true).hasNoAttachment)
        #expect(!rules(hasImage: true, hasPoll: true).hasNoAttachment)
    }

    // MARK: - reveal anchor

    @Test func revealDoesNotAlignTopWhenBlockIsShorterThanViewport() {
        #expect(!CreatePostAttachmentRules.revealAlignsTop(blockHeight: 200, viewportHeight: 500))
    }

    @Test func revealDoesNotAlignTopWhenBlockFitsViewportExactly() {
        #expect(!CreatePostAttachmentRules.revealAlignsTop(blockHeight: 500, viewportHeight: 500))
    }

    @Test func revealAlignsTopWhenBlockIsTallerThanViewport() {
        #expect(CreatePostAttachmentRules.revealAlignsTop(blockHeight: 800, viewportHeight: 500))
    }

    @Test func revealDoesNotAlignTopBeforeAnythingIsMeasured() {
        #expect(!CreatePostAttachmentRules.revealAlignsTop(blockHeight: 0, viewportHeight: 0))
    }
}
