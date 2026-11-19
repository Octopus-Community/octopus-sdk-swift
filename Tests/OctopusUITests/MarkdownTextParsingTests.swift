//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// The markdown parser of the iOS 13–14 fallback (`MarkdownText`): a link whose URL is invalid is shown as plain
/// text instead of crashing the rendering, and emphasis nests with links both ways, as `AttributedString` markdown
/// does from iOS 15. Main-actor bound like every SwiftUI `View`.
@MainActor
struct MarkdownTextParsingTests {
    private let markdownText = MarkdownText("")

    private func links(in text: String) -> [URL] {
        markdownText.parse(text: text).compactMap(\.link)
    }

    private func plainText(of text: String) -> String {
        markdownText.parse(text: text).map(\.content).joined()
    }

    @Test func validMarkdownLinkKeepsItsUrl() {
        #expect(links(in: "I accept the [Terms](https://example.com/terms)")
                == [URL(string: "https://example.com/terms")!])
        #expect(plainText(of: "I accept the [Terms](https://example.com/terms)") == "I accept the Terms")
    }

    @Test func markdownLinkWithAnInvalidUrlShowsItsLabelAsPlainText() {
        let text = "I accept the [Terms](https://exa mple.com/é) today"

        #expect(links(in: text).isEmpty)
        #expect(plainText(of: text) == "I accept the Terms today")
    }

    @Test func bareUrlWithAnInvalidCharacterStaysPlainText() {
        let text = "Read https://example.com/règles first"

        #expect(links(in: text).isEmpty)
        #expect(plainText(of: text) == text)
    }

    @Test func validBareUrlKeepsItsLink() {
        #expect(links(in: "Read www.example.com/rules first") == [URL(string: "https://www.example.com/rules")!])
    }

    @Test func linkUrlIsStrictOnEveryOS() {
        #expect(MarkdownText.linkURL("https://exa mple.com/é") == nil)
        #expect(MarkdownText.linkURL("https://example.com/terms") == URL(string: "https://example.com/terms"))
    }

    @Test func linkInsideBoldIsBoldAndKeepsItsUrl() {
        let terms = URL(string: "https://example.com/terms")!

        #expect(markdownText.parse(text: "**Read the [terms](https://example.com/terms)** first.") == [
            .init(content: "Read the ", isBold: true),
            .init(content: "terms", isBold: true, link: terms),
            .init(content: " first."),
        ])
    }

    @Test func linkInsideItalicIsItalicAndKeepsItsUrl() {
        let rules = URL(string: "https://example.com/rules")!

        #expect(markdownText.parse(text: "_See the [rules](https://example.com/rules)_") == [
            .init(content: "See the ", isItalic: true),
            .init(content: "rules", isItalic: true, link: rules),
        ])
    }

    @Test func italicInsideALinkLabelKeepsItsStyle() {
        let etiquette = URL(string: "https://example.com/etiquette")!

        #expect(markdownText.parse(text: "I will follow the [*trail etiquette*](https://example.com/etiquette)") == [
            .init(content: "I will follow the "),
            .init(content: "trail etiquette", isItalic: true, link: etiquette),
        ])
    }

    @Test func boldInsideALinkLabelKeepsItsStyle() {
        let terms = URL(string: "https://example.com/terms")!

        #expect(markdownText.parse(text: "[the **club** terms](https://example.com/terms)") == [
            .init(content: "the ", link: terms),
            .init(content: "club", isBold: true, link: terms),
            .init(content: " terms", link: terms),
        ])
    }

    @Test func italicNestedInBoldIsBoth() {
        #expect(markdownText.parse(text: "**bold _and italic_**") == [
            .init(content: "bold ", isBold: true),
            .init(content: "and italic", isBold: true, isItalic: true),
        ])
    }

    @Test func bareUrlInsideItalicIsALink() {
        #expect(markdownText.parse(text: "*see https://example.com/b*") == [
            .init(content: "see ", isItalic: true),
            .init(content: "https://example.com/b", isItalic: true, link: URL(string: "https://example.com/b")!),
        ])
    }

    @Test func invalidLinkInsideBoldKeepsTheBoldLabelAsPlainText() {
        #expect(markdownText.parse(text: "**[Terms](https://exa mple.com/é)** today") == [
            .init(content: "Terms", isBold: true),
            .init(content: " today"),
        ])
    }

    /// Paired with one of a word, the underscores of a URL's query once cut the URL: its link opened the part
    /// before them.
    @Test func underscoresInsideWordsAndUrlsAreNoEmphasis() {
        let url = "https://x.com/?utm_source=a&utm_medium=b"

        #expect(markdownText.parse(text: "Hello my_friend, see \(url)") == [
            .init(content: "Hello my_friend, see "),
            .init(content: url, link: URL(string: url)!),
        ])
        #expect(markdownText.parse(text: "[my_file_name](https://example.com/f) and my_var_name") == [
            .init(content: "my_file_name", link: URL(string: "https://example.com/f")!),
            .init(content: " and my_var_name"),
        ])
    }

    @Test func underscoresAtWordEdgesAreEmphasis() {
        #expect(markdownText.parse(text: "a _soft_ and __hard__ word.") == [
            .init(content: "a "),
            .init(content: "soft", isItalic: true),
            .init(content: " and "),
            .init(content: "hard", isBold: true),
            .init(content: " word."),
        ])
    }

    @Test func plainBoldAndItalicCarryNoLink() {
        #expect(markdownText.parse(text: "__Bold__ and *italic*") == [
            .init(content: "Bold", isBold: true),
            .init(content: " and "),
            .init(content: "italic", isItalic: true),
        ])
    }
}
