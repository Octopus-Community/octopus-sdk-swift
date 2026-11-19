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
            cta: WritableCTA(url: URL(string: "https://example.com")!, label: "See more")
        )
        let proto = post.rwOctoObject(uploadIds: [], imagesAreOptimized: [])
        #expect(proto.content.post.hasCta)
        #expect(proto.content.post.cta.text == "See more")
        #expect(proto.content.post.cta.targetLink == "https://example.com")
        #expect(!proto.content.post.cta.hasTextLanguage)
        #expect(proto.content.post.cta.textTranslations.isEmpty)
    }

    @Test func rwOctoObjectIncludesPerLanguageLabelsWhenSet() {
        let post = WritablePost(
            topicId: "topic-id",
            text: "hello hello",
            cta: WritableCTA(
                url: URL(string: "https://example.com")!, label: "Start",
                perLanguageLabels: PerLanguageLabels(
                    defaultLanguageCode: "en", translations: ["fr": "Démarrer", "es-419": "Empezar"]))
        )
        let cta = post.rwOctoObject(uploadIds: [], imagesAreOptimized: []).content.post.cta
        #expect(cta.text == "Start")
        #expect(cta.textLanguage == "en")
        #expect(cta.textTranslations == ["fr": "Démarrer", "es-419": "Empezar"])
    }

    @Test func rwOctoObjectOmitsCtaWhenNil() {
        let post = WritablePost(
            topicId: "topic-id",
            text: "hello hello",
            cta: nil
        )
        let proto = post.rwOctoObject(uploadIds: [], imagesAreOptimized: [])
        #expect(!proto.content.post.hasCta)
    }
}
