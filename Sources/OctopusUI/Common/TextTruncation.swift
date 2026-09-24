//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Normalizes line separators to `"\n"`.
///
/// Swift treats `"\r\n"` as a single `Character` (one extended grapheme cluster), so
/// `split(separator: "\n")` never splits on it and `character == "\n"` never matches it: on a
/// CRLF (or lone-CR) body, the `maxLines` rule silently becomes a no-op. Normalizing first makes
/// a CRLF body split into lines exactly like its `"\n"` equivalent.
///
/// Only `TextTruncation.truncate(_ text: String)` needs this. Foundation's markdown parser
/// already normalizes both `"\r\n"` and `"\r"` to `"\n"` while parsing, so
/// `TextTruncation.truncate(_ text: AttributedString)` receives already-normalized text in
/// production (`RichText` always parses the markdown before cutting it).
private func normalizeLineSeparators(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
}

/// How a user-generated text is shortened before being displayed with a "See more" suffix.
///
/// This is the single definition of the rule: keep at most `maxLength` characters, then at most
/// `maxLines` `\n`-separated lines, then trim whitespace off both ends of what's kept.
struct TextTruncation: Equatable {
    let maxLength: Int
    let maxLines: Int

    init(maxLength: Int = 200, maxLines: Int = 4) {
        self.maxLength = maxLength
        self.maxLines = maxLines
    }

    /// Truncates a plain string. Intended for VoiceOver labels and the pre-iOS 15 rendering path,
    /// which cannot use the attributed rendition.
    func truncate(_ text: String) -> (text: String, isTruncated: Bool) {
        let normalized = normalizeLineSeparators(text)
        let kept = normalized
            .prefix(maxLength)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(maxLines)
            .joined(separator: "\n")
        // `kept` is always a genuine prefix of `normalized`: splitting on a single-character
        // separator and rejoining the first N segments with that same separator reproduces the
        // source exactly, up to (but excluding) the N-th separator, or the whole string if there
        // are fewer than N segments.
        let cut = normalized.index(normalized.startIndex, offsetBy: kept.count)

        // "isTruncated" means non-blank content was dropped, checked *before* trimming: trimming
        // a run of blank lines or trailing spaces must not, by itself, advertise a "... See more"
        // that expands to nothing new.
        let isTruncated = normalized[cut...].contains { !$0.isWhitespace }

        return (kept.trimmingCharacters(in: .whitespacesAndNewlines), isTruncated)
    }

    /// Truncates the rendered text. Attributes ride along with the characters they cover, so a
    /// link whose label is cut in half keeps pointing at its complete URL — which is exactly why
    /// truncation happens here, after the markdown has been parsed, and not on the source string.
    ///
    /// Expects line separators already normalized to `"\n"` — see `normalizeLineSeparators(_:)`.
    @available(iOS 15.0, *)
    func truncate(_ text: AttributedString) -> (text: AttributedString, isTruncated: Bool) {
        let characters = text.characters
        var cut = characters.index(characters.startIndex, offsetBy: maxLength,
                                   limitedBy: characters.endIndex) ?? characters.endIndex

        if maxLines > 0 {
            // Within the character budget, keep `maxLines` lines, i.e. cut at the `maxLines`-th
            // line break (the break itself is dropped).
            var lineBreaks = 0
            var index = characters.startIndex
            while index < cut {
                if characters[index] == "\n" {
                    lineBreaks += 1
                    if lineBreaks == maxLines {
                        cut = index
                        break
                    }
                }
                index = characters.index(after: index)
            }
        } else {
            // Mirror the `String` rule: `prefix(maxLength).split(...).prefix(0)` is always empty.
            cut = characters.startIndex
        }

        // "isTruncated" means non-blank content was dropped, checked *before* trimming: trimming
        // a run of blank lines or trailing spaces must not, by itself, advertise a "... See more"
        // that expands to nothing new.
        let isTruncated = characters[cut...].contains { !$0.isWhitespace }

        // Trim whitespace off both ends of the kept range by moving the bounds inward, not by
        // rewriting characters — rewriting would shift the annotations (e.g. link ranges) that
        // ride on them.
        var start = characters.startIndex
        while start < cut, characters[start].isWhitespace {
            start = characters.index(after: start)
        }
        var end = cut
        while end > start, characters[characters.index(before: end)].isWhitespace {
            end = characters.index(before: end)
        }

        return (AttributedString(text[start..<end]), isTruncated)
    }
}
