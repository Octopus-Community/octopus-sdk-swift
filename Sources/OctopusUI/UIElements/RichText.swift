//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct RichText: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.urlOpener) private var urlOpener
    @Environment(\.font) private var font

    let text: String
    /// How to shorten the text before display, or `nil` to render it in full. When the policy
    /// actually cuts the text, an inline "... See more" suffix is appended.
    let truncation: TextTruncation?

    init(_ text: String, truncation: TextTruncation? = nil) {
        self.text = text
        self.truncation = truncation
    }

    var body: some View {
        if #available(iOS 15, *) {
            attributedText
        } else {
            legacyText
        }
    }

    @available(iOS 15, *)
    @ViewBuilder
    private var attributedText: some View {
        let parsed = Self.resolvingEmphasis(of: Self.markdown(text), baseFont: font ?? .body)
        let displayed = truncation?.truncate(parsed) ?? (text: parsed, isTruncated: false)
        Group {
            if displayed.isTruncated {
                Text(displayed.text) + Text(verbatim: "... ") + readMore
            } else {
                Text(displayed.text)
            }
        }
        .tint(theme.colors.link)
        .modify { view in
            // Selection is offered only on the full rendition: on a shortened body it would hand
            // the reader the cut text followed by the "See more" label, an interface word rather
            // than content. `textSelection` covers a whole `Text`, so the suffix cannot be
            // excluded from the selection — it is all or nothing.
            if displayed.isTruncated {
                view
            } else {
                view.textSelection(.enabled)
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            urlOpener.open(url: url)
            return .handled
        })
    }

    /// Inline markdown of `text`. Foundation's parser drops the emphasis inside a link label (`[*etiquette*](url)`
    /// comes out upright), so a label that carries some is parsed apart: the link is parsed around a placeholder
    /// character, which is then replaced by the label's own markdown, with the link and the emphasis around it.
    /// Whenever a placeholder cannot be replaced cleanly (it ended up in a URL or outside a link, or merged with a
    /// neighbouring combining mark), the text is parsed as Foundation alone does.
    @available(iOS 15, *)
    static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        func parse(_ markdown: String) -> AttributedString? {
            try? AttributedString(markdown: markdown, options: options)
        }

        func foundationOnly() -> AttributedString { parse(text) ?? AttributedString(text) }
        func holdsPlaceholder(_ url: URL?) -> Bool {
            guard let url else { return false }
            return isPlaceholder(in: url.absoluteString.removingPercentEncoding ?? url.absoluteString)
        }

        let (source, labels) = emphasizedLinkLabels(in: text)
        guard !labels.isEmpty, var parsed = parse(source),
              !parsed.runs.contains(where: { holdsPlaceholder($0.link) || holdsPlaceholder($0.imageURL) }) else {
            return foundationOnly()
        }
        for (placeholder, label) in labels {
            guard let index = parsed.characters.firstIndex(of: placeholder) else { return foundationOnly() }
            let range = index..<parsed.characters.index(after: index)
            let around = parsed[range].runs.first!.attributes
            // Brackets that made no link (escaped, in a code span or raw HTML, with a rejected URL) are literal text.
            guard around.link != nil || around.imageURL != nil,
                  var labelText = labelMarkdown(label, parse: parse) else { return foundationOnly() }
            let outerIntent = around.inlinePresentationIntent ?? []
            for run in labelText.runs {
                var attributes = around
                let intent = outerIntent.union(run.inlinePresentationIntent ?? [])
                attributes.inlinePresentationIntent = intent.isEmpty ? nil : intent
                labelText[run.range].setAttributes(attributes)
            }
            parsed.replaceSubrange(range, with: labelText)
        }
        return isPlaceholder(in: String(parsed.characters)) ? foundationOnly() : parsed
    }

    /// The markdown of a link label, parsed between its brackets: delimiters at its edges then flank the same
    /// punctuation as in the link, instead of the start and end of a text. `nil` when the brackets do not come out
    /// as the label's first and last characters (a combining mark at its start merges with the bracket).
    @available(iOS 15, *)
    private static func labelMarkdown(_ label: String, parse: (String) -> AttributedString?) -> AttributedString? {
        guard let bracketed = parse("[" + label + "]") else { return nil }
        let characters = bracketed.characters
        guard characters.count > 2, characters.first == "[", characters.last == "]" else { return nil }
        return AttributedString(bracketed[characters.index(after: characters.startIndex)
                                          ..< characters.index(before: characters.endIndex)])
    }

    /// Unicode private use area, where the placeholders of the link labels are taken.
    private static let placeholders: ClosedRange<UInt32> = 0xE000...0xF8FF

    private static func isPlaceholder(in text: String) -> Bool {
        text.unicodeScalars.contains { placeholders.contains($0.value) }
    }

    /// `text` with the label of each link that holds emphasis markers replaced by a placeholder character, and the
    /// labels so replaced. No label is replaced when `text` already holds a character of the placeholders' range.
    private static func emphasizedLinkLabels(in text: String)
        -> (source: String, labels: [(placeholder: Character, label: String)]) {
        guard !isPlaceholder(in: text) else { return (text, []) }
        let nsText = text as NSString
        var source = ""
        var labels: [(placeholder: Character, label: String)] = []
        var location = 0
        for match in emphasizedLinkRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard let scalar = Unicode.Scalar(placeholders.lowerBound + UInt32(labels.count)),
                  placeholders.contains(scalar.value) else { break }
            let labelRange = match.range(at: 1)
            source += nsText.substring(with: NSRange(location: location, length: labelRange.location - location))
            source.unicodeScalars.append(scalar)
            labels.append((Character(scalar), nsText.substring(with: labelRange)))
            location = NSMaxRange(labelRange)
        }
        source += nsText.substring(from: location)
        return (source, labels)
    }

    /// A link whose label holds `*` or `_`; the label is the first group. A label with a backslash escape or a
    /// backtick is left to Foundation: the escape or the code span could reach past the brackets. The label is split at
    /// its first marker only, and the possessive quantifiers never give back what they took: after an unclosed `[`,
    /// a search that tried every marker as the split would take quadratic time on a long text.
    private static let emphasizedLinkRegex = try! NSRegularExpression(
        pattern: "\\[([^\\[\\]`\\\\*_]*[*_][^\\[\\]`\\\\]*+)\\]\\([^()\\s]++\\)")

    /// `text` with the font of each bold or italic run set, derived from `baseFont`, the font the text is displayed
    /// with. SwiftUI renders the emphasis of `AttributedString` markdown through the font of the view, and drops it
    /// on a link, and the bold under a font given a weight heavier than regular (the legal notice's medium):
    /// resolving it into the run's own font keeps it everywhere.
    @available(iOS 15, *)
    static func resolvingEmphasis(of text: AttributedString, baseFont: Font) -> AttributedString {
        var result = text
        for run in text.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let isBold = intent.contains(.stronglyEmphasized)
            let isItalic = intent.contains(.emphasized)
            guard isBold || isItalic else { continue }
            var font = baseFont
            // `bold()` would not win over the weight of the base font, as a run's font.
            if isBold { font = font.weight(.bold) }
            if isItalic { font = font.italic() }
            result[run.range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = font
        }
        return result
    }

    /// Pre-iOS 15 there is no `AttributedString`, and the hand-rolled `MarkdownText` puts its tap
    /// gesture on a whole line — a tap on "See more" would open the link instead of the content.
    /// So the truncated case stays plain text there.
    @ViewBuilder
    private var legacyText: some View {
        let displayed = truncation?.truncate(text) ?? (text: text, isTruncated: false)
        if displayed.isTruncated {
            Text(verbatim: "\(displayed.text)... ") + readMore
        } else {
            MarkdownText(displayed.text)
        }
    }

    private var readMore: Text {
        Text("Common.ReadMore", bundle: .module)
            .fontWeight(.medium)
            .foregroundColor(theme.colors.gray500)
    }
}

/// Markdown rendering of the iOS 13–14 fallback (no `AttributedString`). Internal so its parser can be tested.
struct MarkdownText: View {
    @Environment(\.urlOpener) private var urlOpener

    let input: String

    init(_ text: String) {
        input = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(parseLines(from: input), id: \.id) { line in
                HStack(alignment: .top, spacing: 4) {
                    if line.isBullet {
                        Text(verbatim: "•")
                    }

                    markdownLineView(text: line.content)
                }
            }
        }
    }

    // MARK: - Markdown Line Parser

    struct ParsedLine: Identifiable {
        let id = UUID()
        let isBullet: Bool
        let content: String
    }

    func parseLines(from input: String) -> [ParsedLine] {
        input.components(separatedBy: .newlines).map { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return ParsedLine(isBullet: true, content: String(trimmed.dropFirst(2)))
            } else {
                return ParsedLine(isBullet: false, content: rawLine)
            }
        }
    }

    // MARK: - Markdown Style

    /// A run of text with its style. Bold, italic and link combine: the emphasis nests with links both ways, as in
    /// `AttributedString` markdown.
    struct MarkdownPart: Equatable {
        let content: String
        var isBold = false
        var isItalic = false
        var link: URL?
    }

    @ViewBuilder
    func markdownLineView(text: String) -> some View {
        let parts = parse(text: text)
        // Build the full Text view by concatenating fragments
        let fullText: Text = parts.reduce(Text(verbatim: "")) { acc, part in
            var segment = Text(part.content)
            if part.isItalic {
                segment = segment.italic()
            }
            if part.isBold {
                segment = segment.bold()
            }
            if part.link != nil {
                segment = segment
                    .underline()
                    .foregroundColor(.blue)
            }

            return acc + segment
        }

        fullText
            .fixedSize(horizontal: false, vertical: true)
            .modify { fullText in
                let links = parts.compactMap(\.link)
                if !links.isEmpty {
                    fullText.onTapGesture {
                        urlOpener.open(url: links[0])
                    }
                } else {
                    fullText
                }
            }
    }

    /// The URL of a link, or `nil` when `raw` is not a valid URL. As strict on every OS as `URL(string:)` is on
    /// iOS 13–14, where this fallback renders: from iOS 17, `URL(string:)` would percent-encode what it used to
    /// reject.
    static func linkURL(_ raw: String) -> URL? {
        if #available(iOS 17, *) {
            return URL(string: raw, encodingInvalidCharacters: false)
        }
        return URL(string: raw)
    }

    func parse(text: String) -> [MarkdownPart] {
        var result: [MarkdownPart] = []
        var remaining = text

        struct Pattern {
            let regex: NSRegularExpression
            let handler: (NSTextCheckingResult, String) -> [MarkdownPart]
        }

        func group(_ index: Int, of match: NSTextCheckingResult, in source: String) -> String {
            String(source[Range(match.range(at: index), in: source)!])
        }

        // The content of a link label or of an emphasis is parsed in turn, so that what it contains keeps its style.
        // An underscore between two letters or digits is no delimiter, as in CommonMark (approximated as on
        // Android): paired with one of a word, the underscores of a URL's query would cut the URL, and its link
        // would open the part before them.
        let patterns: [Pattern] = [
            Pattern(regex: try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)"),
                    handler: { match, source in
                        let label = parse(text: group(1, of: match, in: source))
                        // An invalid URL keeps its label, as plain text: never a crash.
                        guard let url = Self.linkURL(group(2, of: match, in: source)) else { return label }
                        return label.map { var part = $0; part.link = url; return part }
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*"),
                    handler: { match, source in bold(parse(text: group(1, of: match, in: source))) }),
            Pattern(regex: try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])__(.+?)__(?![\\p{L}\\p{N}])"),
                    handler: { match, source in bold(parse(text: group(1, of: match, in: source))) }),
            Pattern(regex: try! NSRegularExpression(pattern: "\\*(.+?)\\*"),
                    handler: { match, source in italic(parse(text: group(1, of: match, in: source))) }),
            Pattern(regex: try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])_(.+?)_(?![\\p{L}\\p{N}])"),
                    handler: { match, source in italic(parse(text: group(1, of: match, in: source))) }),
            Pattern(regex: try! NSRegularExpression(pattern: "(https?://[\\w./?=&%-]+|www\\.[\\w./?=&%-]+)"),
                    handler: { match, source in
                        let raw = group(1, of: match, in: source)
                        let prefix = raw.hasPrefix("http") ? "" : "https://"
                        // An invalid URL stays as written, as plain text: never a crash.
                        return [MarkdownPart(content: raw, link: Self.linkURL(prefix + raw))]
                    })
        ]

        while !remaining.isEmpty {
            var earliestMatch: (pattern: Pattern, match: NSTextCheckingResult, range: Range<String.Index>)?

            for pattern in patterns {
                if let match = pattern.regex.firstMatch(in: remaining, range: NSRange(location: 0, length: remaining.utf16.count)),
                   let fullRange = Range(match.range(at: 0), in: remaining) {
                    if earliestMatch == nil || fullRange.lowerBound < earliestMatch!.range.lowerBound {
                        earliestMatch = (pattern, match, fullRange)
                    }
                }
            }

            if let earliest = earliestMatch {
                // Add text before the match
                let before = String(remaining[..<earliest.range.lowerBound])
                if !before.isEmpty {
                    result.append(.init(content: before))
                }

                // Add styled content
                result.append(contentsOf: earliest.pattern.handler(earliest.match, remaining))

                // Continue after the match
                remaining = String(remaining[earliest.range.upperBound...])
            } else {
                // No more matches
                result.append(.init(content: remaining))
                break
            }
        }

        return result
    }

    private func bold(_ parts: [MarkdownPart]) -> [MarkdownPart] {
        parts.map { var part = $0; part.isBold = true; return part }
    }

    private func italic(_ parts: [MarkdownPart]) -> [MarkdownPart] {
        parts.map { var part = $0; part.isItalic = true; return part }
    }
}
