//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
struct TextTruncationTests {
    /// Same fixture as `EllipsizableTextTests`: 5 chars, then 6 line breaks.
    private static let sample = "12345\n6\n\n\n78\n\n9"

    // MARK: - String

    @Test func truncatesStringOnChars() throws {
        let result = TextTruncation(maxLength: 5, maxLines: Int.max).truncate(Self.sample)
        #expect(result.text == "12345")
        #expect(result.isTruncated == true)
    }

    @Test func truncatesStringOnCharsKeepingLineBreaks() throws {
        let result = TextTruncation(maxLength: 11, maxLines: Int.max).truncate(Self.sample)
        #expect(result.text == "12345\n6\n\n\n7")
        #expect(result.isTruncated == true)
    }

    @Test func truncatesStringOnLines() throws {
        let twoLines = TextTruncation(maxLength: Int.max, maxLines: 2).truncate(Self.sample)
        #expect(twoLines.text == "12345\n6")
        #expect(twoLines.isTruncated == true)

        // Before trimming, `prefix(6)` of the split keeps "12345", "6", "", "", "78", "" (the
        // 6th of the sample's 7 segments), joined as "12345\n6\n\n\n78\n" — the trailing "\n" is
        // now trimmed off both ends of the kept text.
        let sixLines = TextTruncation(maxLength: Int.max, maxLines: 6).truncate(Self.sample)
        #expect(sixLines.text == "12345\n6\n\n\n78")
        #expect(sixLines.isTruncated == true)
    }

    @Test func truncatesStringOnCharsAndLines() throws {
        let result = TextTruncation(maxLength: 11, maxLines: 6).truncate(Self.sample)
        #expect(result.text == "12345\n6\n\n\n7")
        #expect(result.isTruncated == true)
    }

    @Test func keepsStringIntactWhenItFits() throws {
        let result = TextTruncation().truncate("Short enough")
        #expect(result.text == "Short enough")
        #expect(result.isTruncated == false)
    }

    /// The text has exactly `maxLines` lines (the last one empty, because the text ends on a line
    /// break): `split` produces exactly `maxLines` segments, so `prefix(maxLines)` drops nothing
    /// and re-joining reproduces the original string unchanged — before trimming. The trailing
    /// "\n" is then trimmed off, so the kept text is "a\nb", not "a\nb\n". `isTruncated` is still
    /// `false`: the cut point sits at the very end of the text (nothing at all follows it), so
    /// the "dropped content" predicate finds nothing to report regardless of the trim.
    @Test func keepsStringIntactWhenATrailingLineBreakLandsExactlyOnTheLineLimit() throws {
        let result = TextTruncation(maxLength: Int.max, maxLines: 3).truncate("a\nb\n")
        #expect(result.text == "a\nb")
        #expect(result.isTruncated == false)
    }

    @Test func keepsEmptyStringIntact() throws {
        let result = TextTruncation().truncate("")
        #expect(result.text == "")
        #expect(result.isTruncated == false)
    }

    /// `prefix(maxLength).split(...).prefix(0)` is always empty, regardless of the text: with no
    /// lines allowed, the result collapses to "", truncated unless the text was already empty.
    @Test func truncatesToEmptyStringWhenMaxLinesIsZero() throws {
        let nonEmpty = TextTruncation(maxLength: Int.max, maxLines: 0).truncate("hello")
        #expect(nonEmpty.text == "")
        #expect(nonEmpty.isTruncated == true)

        let empty = TextTruncation(maxLength: Int.max, maxLines: 0).truncate("")
        #expect(empty.text == "")
        #expect(empty.isTruncated == false)
    }

    @Test func defaultPolicyIsTwoHundredCharsAndFourLines() throws {
        let policy = TextTruncation()
        #expect(policy.maxLength == 200)
        #expect(policy.maxLines == 4)
    }

    // MARK: - AttributedString

    @Test func truncatesAttributedStringWithTheSameRuleAsString() throws {
        guard #available(iOS 15, *) else { return }
        let attributed = AttributedString(Self.sample)

        let onChars = TextTruncation(maxLength: 11, maxLines: Int.max).truncate(attributed)
        #expect(String(onChars.text.characters) == "12345\n6\n\n\n7")
        #expect(onChars.isTruncated == true)

        let onLines = TextTruncation(maxLength: Int.max, maxLines: 2).truncate(attributed)
        #expect(String(onLines.text.characters) == "12345\n6")
        #expect(onLines.isTruncated == true)
    }

    @Test func keepsAttributedStringIntactWhenItFits() throws {
        guard #available(iOS 15, *) else { return }
        let result = TextTruncation().truncate(AttributedString("Short enough"))
        #expect(String(result.text.characters) == "Short enough")
        #expect(result.isTruncated == false)
    }

    /// The point of the whole ticket: the visible text is cut, the tap target is not.
    @Test func cuttingInsideAnAutolinkedURLKeepsTheFullURL() throws {
        guard #available(iOS 15, *) else { return }
        let full = URL(string: "https://example.com/a/very/long/path?with=query")!
        let attributed = try AttributedString(
            markdown: "Voir ici https://example.com/a/very/long/path?with=query et la suite",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))

        let result = TextTruncation(maxLength: 30, maxLines: Int.max).truncate(attributed)

        #expect(String(result.text.characters) == "Voir ici https://example.com/a")
        #expect(result.isTruncated == true)
        #expect(result.text.runs.last?.link == full)
    }

    @Test func cuttingInsideAMarkdownLabelKeepsTheFullURL() throws {
        guard #available(iOS 15, *) else { return }
        let full = URL(string: "https://example.com/article")!
        let attributed = try AttributedString(
            markdown: "Regarde [ce super article](https://example.com/article) maintenant",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))

        let result = TextTruncation(maxLength: 12, maxLines: Int.max).truncate(attributed)

        #expect(String(result.text.characters) == "Regarde ce s")
        #expect(result.isTruncated == true)
        #expect(result.text.runs.last?.link == full)
    }

    @Test func cuttingAfterALinkKeepsItIntact() throws {
        guard #available(iOS 15, *) else { return }
        let full = URL(string: "https://example.com/article")!
        let attributed = try AttributedString(
            markdown: "Regarde [ce super article](https://example.com/article) maintenant",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))

        let result = TextTruncation(maxLength: 30, maxLines: Int.max).truncate(attributed)

        #expect(String(result.text.characters) == "Regarde ce super article maint")
        #expect(result.isTruncated == true)
        #expect(result.text.runs.contains { $0.link == full } == true)
    }

    /// Same regression as `truncatesToEmptyStringWhenMaxLinesIsZero`, for the `AttributedString`
    /// overload: this is exactly the case where the two overloads used to diverge, because the
    /// line-break loop only fires its `maxLines`-th check on a break that never comes when
    /// `maxLines == 0`.
    @Test func truncatesToEmptyAttributedStringWhenMaxLinesIsZero() throws {
        guard #available(iOS 15, *) else { return }
        let nonEmpty = TextTruncation(maxLength: Int.max, maxLines: 0).truncate(AttributedString("hello"))
        #expect(String(nonEmpty.text.characters) == "")
        #expect(nonEmpty.isTruncated == true)

        let empty = TextTruncation(maxLength: Int.max, maxLines: 0).truncate(AttributedString(""))
        #expect(String(empty.text.characters) == "")
        #expect(empty.isTruncated == false)
    }

    @Test func truncatesLinkFreeMarkdownTextThroughTheAttributedOverload() throws {
        guard #available(iOS 15, *) else { return }
        let attributed = try AttributedString(
            markdown: "Hello world, this sentence has no links at all today",
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))

        let result = TextTruncation(maxLength: 11, maxLines: Int.max).truncate(attributed)

        #expect(String(result.text.characters) == "Hello world")
        #expect(result.isTruncated == true)
        #expect(result.text.runs.allSatisfy { $0.link == nil })
    }

    /// The cut is computed on `Character`s (extended grapheme clusters), exactly like
    /// `String.prefix`, so a multi-scalar character sitting right at the boundary is never split:
    /// "é" and "ñ" here are each two Unicode scalars (a base letter plus a combining mark).
    @Test func cutLandsOnAWholeGraphemeNotInsideAMultiScalarCharacter() throws {
        guard #available(iOS 15, *) else { return }
        let combiningAcuteE = "e\u{0301}" // "é" as two Unicode scalars
        let combiningTildeN = "n\u{0303}" // "ñ" as two Unicode scalars
        let text = "ab" + combiningAcuteE + combiningTildeN + "cd"
        let attributed = AttributedString(text)

        // Kept characters: 'a', 'b', "é" (the grapheme immediately before the cut). The first
        // dropped character is "ñ" (the grapheme immediately after the cut).
        let result = TextTruncation(maxLength: 3, maxLines: Int.max).truncate(attributed)

        #expect(String(result.text.characters) == "ab" + combiningAcuteE)
        #expect(result.text.characters.count == 3)
        #expect(result.isTruncated == true)
    }

    // MARK: - Trimming the cut result

    /// A cut landing inside a run of blank lines must not leave those blank lines dangling in the
    /// kept text. By hand: `prefix(200)` keeps everything (well under budget); splitting on "\n"
    /// yields ["Line one", "Line two", "", "", "", "", "", "Line eight"] (8 segments: 1 break
    /// after "Line one", 6 after "Line two"); `prefix(4)` keeps the first 4 segments, joined as
    /// "Line one\nLine two\n\n" — trimming removes the trailing "\n\n".
    @Test func trimsTrailingBlankLinesLeftByACutInsideARunOfThem() throws {
        let body = "Line one\nLine two\n\n\n\n\n\nLine eight"
        let result = TextTruncation().truncate(body)
        #expect(result.text == "Line one\nLine two")
        #expect(result.isTruncated == true)
    }

    @Test func trimsTrailingBlankLinesLeftByACutInsideARunOfThem_attributed() throws {
        guard #available(iOS 15, *) else { return }
        let body = "Line one\nLine two\n\n\n\n\n\nLine eight"
        let result = TextTruncation().truncate(AttributedString(body))
        #expect(String(result.text.characters) == "Line one\nLine two")
        #expect(result.isTruncated == true)
    }

    /// A cut landing right after a run of trailing spaces must not leave those spaces in the kept
    /// text. By hand: `prefix(7)` of "Hello     world" (5 letters, 5 spaces, "world") keeps
    /// "Hello  " (5 letters + 2 spaces); there is no "\n", so the line rule keeps that whole
    /// prefix; trimming removes the 2 trailing spaces, leaving "Hello".
    @Test func trimsTrailingSpacesLeftByACutAfterThem() throws {
        let result = TextTruncation(maxLength: 7, maxLines: Int.max).truncate("Hello     world")
        #expect(result.text == "Hello")
        #expect(result.isTruncated == true)
    }

    @Test func trimsTrailingSpacesLeftByACutAfterThem_attributed() throws {
        guard #available(iOS 15, *) else { return }
        let result = TextTruncation(maxLength: 7, maxLines: Int.max).truncate(AttributedString("Hello     world"))
        #expect(String(result.text.characters) == "Hello")
        #expect(result.isTruncated == true)
    }

    // MARK: - isTruncated means non-blank content was dropped

    /// By hand, with the default policy (200 chars, 4 lines): "Short body" plus 6 "\n" splits
    /// into 7 segments, the last 6 empty; `prefix(4)` keeps "Short body", "", "", "" (3 of the 6
    /// blank lines), joined as "Short body\n\n\n". Before trimming, everything from the cut to the
    /// end is the 3 remaining "\n" — all whitespace, so nothing non-blank was dropped: not
    /// truncated, even though the string did shrink.
    @Test func isNotTruncatedWhenOnlyTrailingBlankLinesAreDropped() throws {
        let result = TextTruncation().truncate("Short body\n\n\n\n\n\n")
        #expect(result.isTruncated == false)
    }

    @Test func isNotTruncatedWhenOnlyTrailingBlankLinesAreDropped_attributed() throws {
        guard #available(iOS 15, *) else { return }
        let result = TextTruncation().truncate(AttributedString("Short body\n\n\n\n\n\n"))
        #expect(result.isTruncated == false)
    }

    /// By hand: "Hello" plus 400 spaces is 405 characters, no "\n"; `prefix(200)` keeps "Hello"
    /// plus 195 spaces. Everything from the cut to the end is the remaining 205 spaces — all
    /// whitespace, so not truncated.
    @Test func isNotTruncatedWhenOnlyTrailingSpacesAreDropped() throws {
        let result = TextTruncation().truncate("Hello" + String(repeating: " ", count: 400))
        #expect(result.isTruncated == false)
    }

    @Test func isNotTruncatedWhenOnlyTrailingSpacesAreDropped_attributed() throws {
        guard #available(iOS 15, *) else { return }
        let result = TextTruncation().truncate(AttributedString("Hello" + String(repeating: " ", count: 400)))
        #expect(result.isTruncated == false)
    }

    /// The predicate must still fire when real content is dropped and the kept text happens to
    /// end flush against the cut — no whitespace involved, so trimming plays no part here. By
    /// hand: `prefix(5)` of "HelloWorld" is "Hello" (no trailing whitespace to trim); "World"
    /// remains past the cut.
    @Test func isTruncatedWhenContentIsDroppedEvenIfTheKeptTextEndsFlush() throws {
        let result = TextTruncation(maxLength: 5, maxLines: Int.max).truncate("HelloWorld")
        #expect(result.text == "Hello")
        #expect(result.isTruncated == true)
    }

    @Test func isTruncatedWhenContentIsDroppedEvenIfTheKeptTextEndsFlush_attributed() throws {
        guard #available(iOS 15, *) else { return }
        let result = TextTruncation(maxLength: 5, maxLines: Int.max).truncate(AttributedString("HelloWorld"))
        #expect(String(result.text.characters) == "Hello")
        #expect(result.isTruncated == true)
    }

    // MARK: - Line-separator normalization (String overload only)

    /// Swift treats `"\r\n"` as a single `Character`, so without normalization `split(separator:
    /// "\n")` never splits a CRLF body and the `maxLines` rule becomes a no-op on it. A CRLF body
    /// must be line-limited exactly like its `"\n"` equivalent: by hand, both normalize/split into
    /// ["a", "b", "c", "d", "e"], `prefix(3)` keeps "a", "b", "c", joined as "a\nb\nc", with "d"
    /// past the cut.
    @Test func normalizesCRLFBeforeApplyingTheLinesRule() throws {
        let policy = TextTruncation(maxLength: Int.max, maxLines: 3)
        let crlfResult = policy.truncate("a\r\nb\r\nc\r\nd\r\ne")
        let lfResult = policy.truncate("a\nb\nc\nd\ne")
        #expect(crlfResult.text == "a\nb\nc")
        #expect(crlfResult.isTruncated == true)
        #expect(crlfResult == lfResult)
    }

    /// A lone `"\r"` (old Mac-style line ending) must normalize the same way.
    @Test func normalizesLoneCRBeforeApplyingTheLinesRule() throws {
        let policy = TextTruncation(maxLength: Int.max, maxLines: 3)
        let crResult = policy.truncate("a\rb\rc\rd\re")
        let lfResult = policy.truncate("a\nb\nc\nd\ne")
        #expect(crResult == lfResult)
    }

    // MARK: - Invariant: both overloads implement the same rule

    /// The `String` and `AttributedString` overloads implement the same rule with structurally
    /// different code (character-prefix/split/rejoin vs. scanning for the n-th line break within
    /// a character budget). Walk a matrix of texts x policies and assert they always agree, so a
    /// future change to one does not silently drift from the other.
    ///
    /// The `String` overload normalizes `"\r\n"`/`"\r"` to `"\n"` before cutting, while the
    /// `AttributedString` overload assumes that normalization already happened (real callers get
    /// it for free from the markdown parser). This matrix feeds the same raw text to both
    /// overloads without going through a parser, so its fixtures must stay free of `"\r"` —
    /// otherwise the two overloads would legitimately disagree, not because of a bug but because
    /// only one of them is documented to normalize.
    @Test func stringAndAttributedStringOverloadsAgree() throws {
        guard #available(iOS 15, *) else { return }
        let combiningAcuteE = "e\u{0301}" // "é" as two Unicode scalars
        let combiningTildeN = "n\u{0303}" // "ñ" as two Unicode scalars
        let texts = [
            "",                 // empty
            "hello world",      // no newline
            Self.sample,        // existing fixture: 5 chars, then 6 line breaks
            "\nleading",        // leading newline
            "trailing\n",       // trailing newline
            "a\n\n\nb",         // consecutive newlines
            "ab" + combiningAcuteE + combiningTildeN + "cd" // multi-scalar graphemes near the cut
        ]
        let maxLengths = [0, 1, 3, 5, 11, Int.max - 1, Int.max]
        let maxLinesValues = [0, 1, 2, 3, 4, 6, Int.max - 1, Int.max]

        for text in texts {
            for maxLength in maxLengths {
                for maxLines in maxLinesValues {
                    let policy = TextTruncation(maxLength: maxLength, maxLines: maxLines)
                    let stringResult = policy.truncate(text)
                    let attributedResult = policy.truncate(AttributedString(text))
                    let context = "text: \(text.debugDescription), maxLength: \(maxLength), maxLines: \(maxLines)"
                    #expect(String(attributedResult.text.characters) == stringResult.text, "\(context)")
                    #expect(attributedResult.isTruncated == stringResult.isTruncated, "\(context)")
                }
            }
        }
    }
}
