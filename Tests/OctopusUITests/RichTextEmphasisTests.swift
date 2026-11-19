//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
@testable import OctopusUI

/// From iOS 15, `RichText` renders `AttributedString` markdown. Its parser drops the emphasis of a link label, so the
/// label is parsed apart; and SwiftUI drops emphasis on a link and, as bold, under a font given a weight heavier than
/// regular (the legal notice's medium), so the emphasis is resolved into the font of each emphasized run, derived
/// from the font the text is displayed with. Main-actor bound like every SwiftUI `View`.
@MainActor
struct RichTextEmphasisTests {
    private let baseFont = Font.system(size: 12).weight(.medium)

    @available(iOS 15, *)
    private func resolved(_ markdown: String) -> AttributedString {
        RichText.resolvingEmphasis(of: RichText.markdown(markdown), baseFont: baseFont)
    }

    /// The run of `text` whose characters are exactly `substring`.
    @available(iOS 15, *)
    private func run(_ substring: String, in text: AttributedString) -> AttributedString.Runs.Run? {
        text.runs.first { String(text[$0.range].characters) == substring }
    }

    /// What Foundation's markdown parser alone gives, the rendering kept when the label cannot be parsed apart.
    @available(iOS 15, *)
    private func foundationMarkdown(_ markdown: String) throws -> AttributedString {
        try AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
    }

    @available(iOS 15, *)
    private func font(of run: AttributedString.Runs.Run?) -> Font? {
        run?[AttributeScopes.SwiftUIAttributes.FontAttribute.self]
    }

    @Test func italicInsideALinkLabelGetsAnItalicFontAndKeepsItsLink() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("I will follow the [*trail etiquette*](https://example.com/etiquette)")

        let link = try #require(run("trail etiquette", in: text))
        #expect(font(of: link) == baseFont.italic())
        #expect(link.link == URL(string: "https://example.com/etiquette"))
    }

    @Test func boldGetsABoldFontOverTheWeightOfTheBaseFont() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("**Be kind on the trail.** Members keep their rights.")

        #expect(font(of: run("Be kind on the trail.", in: text)) == baseFont.weight(.bold))
    }

    @Test func linkInsideBoldGetsABoldFontAndKeepsItsLink() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("**Read the [terms](https://example.com/terms)** first.")

        #expect(font(of: run("Read the ", in: text)) == baseFont.weight(.bold))
        let link = try #require(run("terms", in: text))
        #expect(font(of: link) == baseFont.weight(.bold))
        #expect(link.link == URL(string: "https://example.com/terms"))
    }

    @Test func italicNestedInBoldGetsABoldItalicFont() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("**bold _and italic_**")

        #expect(font(of: run("bold ", in: text)) == baseFont.weight(.bold))
        #expect(font(of: run("and italic", in: text)) == baseFont.weight(.bold).italic())
    }

    @Test func textWithoutEmphasisKeepsTheFontOfItsView() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("I accept the [privacy notice](https://example.com/privacy) today")

        #expect(text.runs.allSatisfy { font(of: $0) == nil })
        #expect(String(text.characters) == "I accept the privacy notice today")
    }

    @Test func boldInsidePartOfALinkLabelKeepsItsStyleAndTheLinkCoversTheWholeLabel() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("I accept [the **club** terms](https://example.com/terms).")

        #expect(String(text.characters) == "I accept the club terms.")
        let terms = URL(string: "https://example.com/terms")
        #expect(try #require(run("the ", in: text)).link == terms)
        let club = try #require(run("club", in: text))
        #expect(font(of: club) == baseFont.weight(.bold))
        #expect(club.link == terms)
        #expect(try #require(run(" terms", in: text)).link == terms)
    }

    @Test func emphasisAroundALinkAddsToTheEmphasisOfItsLabel() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("**Read [*the terms*](https://example.com/terms)**")

        #expect(font(of: run("Read ", in: text)) == baseFont.weight(.bold))
        let link = try #require(run("the terms", in: text))
        #expect(font(of: link) == baseFont.weight(.bold).italic())
        #expect(link.link == URL(string: "https://example.com/terms"))
    }

    @Test func twoLinksWithEmphasizedLabelsKeepTheirOwnUrl() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("[*rules*](https://example.com/rules) and [**terms**](https://example.com/terms)")

        let rules = try #require(run("rules", in: text))
        #expect(font(of: rules) == baseFont.italic())
        #expect(rules.link == URL(string: "https://example.com/rules"))
        let terms = try #require(run("terms", in: text))
        #expect(font(of: terms) == baseFont.weight(.bold))
        #expect(terms.link == URL(string: "https://example.com/terms"))
    }

    @Test func linkSyntaxInACodeSpanStaysLiteral() throws {
        guard #available(iOS 15, *) else { return }
        let text = resolved("Type `[*a*](https://example.com)` here")

        #expect(String(text.characters) == "Type [*a*](https://example.com) here")
        #expect(text.runs.allSatisfy { $0.link == nil })
    }

    @Test func emphasizedLinkSyntaxInsideALinkUrlKeepsTheUrlIntact() throws {
        guard #available(iOS 15, *) else { return }
        let markdown = "[docs](https://example.com/s?q=[a_b](c))"

        #expect(RichText.markdown(markdown) == (try foundationMarkdown(markdown)))
    }

    @Test func combiningMarkAfterAnEmphasizedLinkShowsNoPlaceholder() throws {
        guard #available(iOS 15, *) else { return }
        let markdown = "[*a*](https://example.com)\u{301} b"

        #expect(RichText.markdown(markdown) == (try foundationMarkdown(markdown)))
    }

    @Test func textHoldingAPrivateUseCharacterIsParsedAsFoundationDoes() throws {
        guard #available(iOS 15, *) else { return }
        let markdown = "\u{E000} [*a*](https://example.com)"

        #expect(RichText.markdown(markdown) == (try foundationMarkdown(markdown)))
    }

    @Test(arguments: [
        "[*a*\\](https://example.com)", "[`a*](https://example.com)`", "`x [a*` b](https://example.com)",
    ])
    func escapeOrCodeSpanAcrossALinkLabelIsParsedAsFoundationDoes(markdown: String) throws {
        guard #available(iOS 15, *) else { return }

        #expect(RichText.markdown(markdown) == (try foundationMarkdown(markdown)))
    }

    @Test(arguments: [
        "\\[*a](https://x.com) b*", "[*a](<b) c*", "<span title=\"[*a*](u)\">x</span>",
        "[*a*](https://exa%zzmple.com) tail",
    ])
    func bracketsThatMakeNoLinkAreParsedAsFoundationDoes(markdown: String) throws {
        guard #available(iOS 15, *) else { return }

        #expect(RichText.markdown(markdown) == (try foundationMarkdown(markdown)))
    }

    @Test func unpairedDelimitersAtTheEdgeOfALabelStayLiteralAsNextToItsBrackets() throws {
        guard #available(iOS 15, *) else { return }
        let text = RichText.markdown("[**\"x*](https://example.com)!")

        #expect(String(text.characters) == "**\"x*!")
        #expect(text.runs.allSatisfy { $0.inlinePresentationIntent == nil })
        #expect(try #require(run("**\"x*", in: text)).link == URL(string: "https://example.com"))
    }

    /// Member-written bodies reach the label search in full, before any truncation: a bracket left open must not
    /// make the search backtrack over the rest of the text.
    @Test func longTextAfterAnUnclosedBracketIsParsedInLinearTime() throws {
        guard #available(iOS 15, *) else { return }
        let markdown = "[" + String(repeating: "*_", count: 10_000)

        let start = Date()
        let text = RichText.markdown(markdown)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 0.5)
        #expect(text == (try foundationMarkdown(markdown)))
    }
}
