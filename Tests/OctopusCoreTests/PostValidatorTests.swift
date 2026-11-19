//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

struct PostValidatorTests {
    private let validPoll = WritablePoll(options: [.init(text: "Red"), .init(text: "Blue")])

    private func textError(_ result: Result<Void, Validators.Post.TextError>) -> Validators.Post.TextError? {
        if case let .failure(error) = result { return error }
        return nil
    }

    // MARK: - Text, with a poll (with or without an image)

    @Test func oneCharacterTextIsAcceptedWhenAPollIsPresent() {
        #expect(textError(Validators.Post.validate(text: "?", hasPoll: true)) == nil)
    }

    @Test func maxLengthTextIsAcceptedWhenAPollIsPresent() {
        let text = String(repeating: "a", count: Validators.Post.maxTextLength)
        #expect(textError(Validators.Post.validate(text: text, hasPoll: true)) == nil)
    }

    @Test func textAboveMaxLengthIsRejectedWhenAPollIsPresent() {
        let text = String(repeating: "a", count: Validators.Post.maxTextLength + 1)
        #expect(textError(Validators.Post.validate(text: text, hasPoll: true)) == .tooLong)
    }

    @Test func emptyTextIsRejectedWhenAPollIsPresent() {
        #expect(textError(Validators.Post.validate(text: "", hasPoll: true)) == .empty)
    }

    // MARK: - Text, without a poll

    @Test func minimumTextLengthIsOneCharacter() {
        #expect(Validators.Post.minTextLength == 1)
        #expect(Validators.Post.maxTextLength == 5000)
    }

    @Test(arguments: ["a", "Bravo !", "Fini !"])
    func shortTextIsAcceptedWithoutAPoll(text: String) {
        #expect(textError(Validators.Post.validate(text: text, hasPoll: false)) == nil)
    }

    @Test(arguments: [false, true])
    func whitespaceOnlyTextIsEmpty(hasPoll: Bool) {
        #expect(textError(Validators.Post.validate(text: "  \n ", hasPoll: hasPoll)) == .empty)
    }

    @Test func minLengthTextIsAcceptedWithoutAPoll() {
        let text = String(repeating: "a", count: Validators.Post.minTextLength)
        #expect(textError(Validators.Post.validate(text: text, hasPoll: false)) == nil)
    }

    @Test func tooShortIsIgnoredOnDemand() {
        #expect(textError(Validators.Post.validate(text: "a", hasPoll: false, ignoreTooShort: true)) == nil)
    }

    // MARK: - Text, when the community makes it optional

    enum Draft: CaseIterable, Sendable {
        case empty, whitespace, short, minLength, tooLong

        var text: String {
            switch self {
            case .empty: ""
            case .whitespace: "  \n "
            case .short: "abc"
            case .minLength: String(repeating: "a", count: Validators.Post.minTextLength)
            case .tooLong: String(repeating: "a", count: Validators.Post.maxTextLength + 1)
            }
        }
    }

    @Test(arguments: [Draft.empty, .whitespace], [false, true])
    func blankTextIsAcceptedWithAnImageWhenTextIsOptional(draft: Draft, hasPoll: Bool) {
        let result = Validators.Post.validate(text: draft.text, hasPoll: hasPoll, hasImage: true,
                                              textRequired: false)
        #expect(textError(result) == nil)
    }

    @Test(arguments: [false, true])
    func emptyTextIsRejectedWithoutAnImageEvenWhenTextIsOptional(hasPoll: Bool) {
        let result = Validators.Post.validate(text: "", hasPoll: hasPoll, hasImage: false, textRequired: false)
        #expect(textError(result) == .empty)
    }

    @Test(arguments: [false, true])
    func emptyTextIsRejectedWithAnImageWhenTextIsRequired(hasPoll: Bool) {
        let result = Validators.Post.validate(text: "", hasPoll: hasPoll, hasImage: true, textRequired: true)
        #expect(textError(result) == .empty)
    }

    @Test func whitespaceTextIsEmptyWhenTextIsRequired() {
        // Blank text is no text: refused as empty, with no too-short message.
        let result = Validators.Post.validate(text: "   ", hasPoll: false, hasImage: true, textRequired: true)
        #expect(textError(result) == .empty)
    }

    @Test func textStaysRequiredByDefault() {
        #expect(textError(Validators.Post.validate(text: "", hasPoll: false, hasImage: true)) == .empty)
    }

    /// As soon as the draft carries text, the current rules apply whatever the setting and the image.
    @Test(arguments: [
        (textRequired: false, hasImage: false),
        (textRequired: false, hasImage: true),
        (textRequired: true, hasImage: false),
        (textRequired: true, hasImage: true)
    ], [false, true])
    func textRulesAreUnchangedOnceTextIsPresent(_ setting: (textRequired: Bool, hasImage: Bool), hasPoll: Bool) {
        for draft in [Draft.short, .minLength, .tooLong] {
            let result = Validators.Post.validate(text: draft.text, hasPoll: hasPoll, hasImage: setting.hasImage,
                                                  textRequired: setting.textRequired)
            let currentRule = Validators.Post.validate(text: draft.text, hasPoll: hasPoll)
            #expect(textError(result) == textError(currentRule), "draft \(draft)")
        }
    }

    @Test func shortTextIsAcceptedWithAnImageWhenTextIsOptional() {
        let result = Validators.Post.validate(text: Draft.short.text, hasPoll: false, hasImage: true,
                                              textRequired: false)
        #expect(textError(result) == nil)
    }

    // MARK: - Published text

    @Test func blankTextIsSentEmptyWhenTextIsOptional() {
        #expect(Validators.Post.publishableText("  \n ", hasImage: true, textRequired: false) == "")
    }

    @Test func textIsSentAsTypedWhenItIsNotBlank() {
        #expect(Validators.Post.publishableText(" Hello ", hasImage: true, textRequired: false) == " Hello ")
    }

    @Test func blankTextIsSentAsTypedWhenTextIsRequired() {
        #expect(Validators.Post.publishableText("   ", hasImage: true, textRequired: true) == "   ")
    }

    @Test func blankTextIsSentAsTypedWithoutImage() {
        #expect(Validators.Post.publishableText("   ", hasImage: false, textRequired: false) == "   ")
    }

    // MARK: - Poll

    @Test func noPollIsValid() {
        #expect(Validators.Post.validate(poll: nil))
    }

    @Test func pollWithTwoOptionsIsValid() {
        #expect(Validators.Post.validate(poll: validPoll))
    }

    @Test func pollWithASingleOptionIsInvalid() {
        #expect(!Validators.Post.validate(poll: WritablePoll(options: [.init(text: "Red")])))
    }

    // MARK: - Whole post

    @Test func mixedPostWithOneCharacterTextIsValid() {
        let post = WritablePost(topicId: "topic-id", text: "?", images: [Data([0x01])], poll: validPoll)
        #expect(Validators.Post.validate(post: post))
    }

    @Test func mixedPostWithAnInvalidPollIsInvalid() {
        let post = WritablePost(topicId: "topic-id", text: "Which one?", images: [Data([0x01])],
                                poll: WritablePoll(options: [.init(text: "Red")]))
        #expect(!Validators.Post.validate(post: post))
    }

    @Test func imagePostWithAShortTextIsValid() {
        let post = WritablePost(topicId: "topic-id", text: "Bravo !", images: [Data([0x01])])
        #expect(Validators.Post.validate(post: post))
    }

    @Test func textPostWithAShortTextIsValid() {
        let post = WritablePost(topicId: "topic-id", text: "Bravo !")
        #expect(Validators.Post.validate(post: post))
    }

    @Test func textPostWithABlankTextIsInvalid() {
        let post = WritablePost(topicId: "topic-id", text: "   ")
        #expect(!Validators.Post.validate(post: post))
    }

    @Test func imageOnlyPostWithoutTextIsValidWhenTextIsOptional() {
        let post = WritablePost(topicId: "topic-id", text: "", images: [Data([0x01])])
        #expect(Validators.Post.validate(post: post, textRequired: false))
    }

    @Test func imageOnlyPostWithoutTextIsInvalidWhenTextIsRequired() {
        let post = WritablePost(topicId: "topic-id", text: "", images: [Data([0x01])])
        #expect(!Validators.Post.validate(post: post))
        #expect(!Validators.Post.validate(post: post, textRequired: true))
    }

    @Test func imageAndPollPostWithoutTextIsValidWhenTextIsOptional() {
        let post = WritablePost(topicId: "topic-id", text: "", images: [Data([0x01])], poll: validPoll)
        #expect(Validators.Post.validate(post: post, textRequired: false))
    }

    @Test func pollOnlyPostWithoutTextIsInvalidEvenWhenTextIsOptional() {
        let post = WritablePost(topicId: "topic-id", text: "", poll: validPoll)
        #expect(!Validators.Post.validate(post: post, textRequired: false))
    }

    @Test func imagePostWithoutTextAndWithAnInvalidPollIsInvalid() {
        let post = WritablePost(topicId: "topic-id", text: "", images: [Data([0x01])],
                                poll: WritablePoll(options: [.init(text: "Red")]))
        #expect(!Validators.Post.validate(post: post, textRequired: false))
    }
}
