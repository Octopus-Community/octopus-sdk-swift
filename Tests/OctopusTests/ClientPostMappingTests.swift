//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import Octopus
import OctopusCore

// Both modules declare a `ClientPost`: the tests exercise the public one.
private typealias ClientPost = Octopus.ClientPost

struct ClientPostMappingTests {
    private func post(medias: [ClientPost.Attachment]) -> ClientPost {
        ClientPost(clientObjectId: "object-id", text: "A text long enough", medias: medias,
                   viewClientObjectButton: nil)
    }

    private func distantImages(count: Int) -> [ClientPost.Attachment] {
        (0..<count).map { .distantImage(URL(string: "https://example.com/\($0).jpg")!) }
    }

    @Test func mediasMapToCoreInOrder() {
        let data = Data([1, 2, 3])
        let url = URL(string: "https://example.com/a.jpg")!
        let core = post(medias: [.localImage(data), .distantImage(url), .localImage(Data([4]))]).coreValue

        #expect(core.medias.count == 3)
        guard core.medias.count == 3 else { return }
        guard case let .localImage(first) = core.medias[0] else { Issue.record("first should be local"); return }
        #expect(first == data)
        guard case let .distantImage(second) = core.medias[1] else { Issue.record("second should be distant"); return }
        #expect(second == url)
        guard case let .localImage(third) = core.medias[2] else { Issue.record("third should be local"); return }
        #expect(third == Data([4]))
    }

    @Test func noMediaMapsToAnEmptyList() {
        #expect(post(medias: []).coreValue.medias.isEmpty)
    }

    @Test func tenMediasAreAccepted() throws {
        try ClientPost.validateMediaCount(post(medias: distantImages(count: Validators.Post.maxImageCount)))
    }

    @Test func atMostOneMediaIsAcceptedWithoutTokenProvider() throws {
        try ClientPost.validateMediaCountWithoutTokenProvider(post(medias: []))
        try ClientPost.validateMediaCountWithoutTokenProvider(post(medias: distantImages(count: 1)))
    }

    @Test func twoMediasAreRefusedWithoutTokenProvider() {
        do {
            try ClientPost.validateMediaCountWithoutTokenProvider(post(medias: distantImages(count: 2)))
            Issue.record("expected a validation error")
        } catch {
            guard case let .validation(errors) = error else {
                Issue.record("expected .validation, got \(error)")
                return
            }
            #expect(errors.count == 1)
            #expect(errors.first?.field == .file)
            #expect(errors.first?.message.contains("a single media, 2 were provided") == true)
            #expect(errors.first?.message.contains("tokenProvider") == true)
        }
    }

    @Test func elevenMediasAreRefusedOnTheFileField() {
        let count = Validators.Post.maxImageCount + 1
        do {
            try ClientPost.validateMediaCount(post(medias: distantImages(count: count)))
            Issue.record("expected a validation error")
        } catch {
            guard case let .validation(errors) = error else {
                Issue.record("expected .validation, got \(error)")
                return
            }
            #expect(errors.count == 1)
            #expect(errors.first?.field == .file)
            #expect(errors.first?.message.contains("at most 10") == true)
            #expect(errors.first?.message.contains("\(count)") == true)
        }
    }
}

/// Deprecated APIs (tests are still here to ensure old APIs can still be called)
extension ClientPostMappingTests {
    @Test func deprecatedAttachmentInitMapsToOneMedia() {
        let url = URL(string: "https://example.com/a.jpg")!
        let withAttachment = ClientPost(clientObjectId: "id", text: "text", attachment: .distantImage(url),
                                        viewClientObjectButtonText: nil)
        #expect(withAttachment.medias.count == 1)
        let withoutAttachment = ClientPost(clientObjectId: "id", text: "text", attachment: nil,
                                           viewClientObjectButtonText: nil)
        #expect(withoutAttachment.medias.isEmpty)
        let withSignature = ClientPost(clientObjectId: "id", topicId: "topic", text: "text",
                                       attachment: .localImage(Data([1])), viewClientObjectButtonText: nil,
                                       signature: "sig")
        #expect(withSignature.medias.count == 1)
        #expect(withSignature.signature == "sig")
        #expect(withSignature.groupId == "topic")
    }

    @Test func deprecatedAttachmentReturnsFirst() {
        let url = URL(string: "https://example.com/a.jpg")!
        let multi = post(medias: [.distantImage(url), .localImage(Data([1]))])
        guard case let .distantImage(first)? = multi.attachment else {
            Issue.record("attachment should be the first media")
            return
        }
        #expect(first == url)
        #expect(post(medias: []).attachment == nil)
    }
}
