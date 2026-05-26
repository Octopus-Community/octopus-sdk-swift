//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct WritablePostCTATests {
    @Test func rwOctoObjectIncludesCtaWhenSet() {
        let post = WritablePost(
            topicId: "topic-id",
            text: "hello hello",
            attachment: nil,
            cta: WritableCTA(url: URL(string: "https://example.com")!, label: "See more")
        )
        let proto = post.rwOctoObject(imageIsCompressed: false)
        #expect(proto.content.post.hasCta)
        #expect(proto.content.post.cta.text == "See more")
        #expect(proto.content.post.cta.targetLink == "https://example.com")
    }

    @Test func rwOctoObjectOmitsCtaWhenNil() {
        let post = WritablePost(
            topicId: "topic-id",
            text: "hello hello",
            attachment: nil,
            cta: nil
        )
        let proto = post.rwOctoObject(imageIsCompressed: false)
        #expect(!proto.content.post.hasCta)
    }
}
