//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct RichText: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.urlOpener) private var urlOpener

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
        let parsed = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
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

private struct MarkdownText: View {
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

    enum MarkdownStyle {
        case normal, italic, bold, link(URL)
    }

    struct MarkdownPart {
        let content: String
        let style: MarkdownStyle
    }

    @ViewBuilder
    func markdownLineView(text: String) -> some View {
        let parts = parse(text: text)
        // Build the full Text view by concatenating fragments
        let fullText: Text = parts.reduce(Text(verbatim: "")) { acc, part in
            var segment = Text(part.content)

            switch part.style {
            case .normal:
                break
            case .italic:
                segment = segment.italic()
            case .bold:
                segment = segment.bold()
            case .link:
                segment = segment
                    .underline()
                    .foregroundColor(.blue)
            }

            return acc + segment
        }

        fullText
            .fixedSize(horizontal: false, vertical: true)
            .modify { fullText in
                let links = parts.compactMap {
                    switch $0.style {
                    case let .link(url):
                        return url
                    default: return nil
                    }
                }
                if !links.isEmpty {
                    fullText.onTapGesture {
                        urlOpener.open(url: links[0])
                    }
                } else {
                    fullText
                }
            }
    }

    func parse(text: String) -> [MarkdownPart] {
        var result: [MarkdownPart] = []
        var remaining = text

        struct Pattern {
            let regex: NSRegularExpression
            let handler: (NSTextCheckingResult, String) -> (String, MarkdownStyle)
        }

        let patterns: [Pattern] = [
            Pattern(regex: try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)"),
                    handler: { match, source in
                        let labelRange = Range(match.range(at: 1), in: source)!
                        let urlRange = Range(match.range(at: 2), in: source)!
                        let label = String(source[labelRange])
                        let url = URL(string: String(source[urlRange]))!
                        return (label, .link(url))
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*"),
                    handler: { match, source in
                        let range = Range(match.range(at: 1), in: source)!
                        return (String(source[range]), .bold)
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "__(.+?)__"),
                    handler: { match, source in
                        let range = Range(match.range(at: 1), in: source)!
                        return (String(source[range]), .bold)
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "\\*(.+?)\\*"),
                    handler: { match, source in
                        let range = Range(match.range(at: 1), in: source)!
                        return (String(source[range]), .italic)
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "_(.+?)_"),
                    handler: { match, source in
                        let range = Range(match.range(at: 1), in: source)!
                        return (String(source[range]), .italic)
                    }),
            Pattern(regex: try! NSRegularExpression(pattern: "(https?://[\\w./?=&%-]+|www\\.[\\w./?=&%-]+)"),
                    handler: { match, source in
                        let range = Range(match.range(at: 1), in: source)!
                        let raw = String(source[range])
                        let prefix = raw.hasPrefix("http") ? "" : "https://"
                        return (raw, .link(URL(string: prefix + raw)!))
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
                    result.append(.init(content: before, style: .normal))
                }

                // Add styled content
                let (content, style) = earliest.pattern.handler(earliest.match, remaining)
                result.append(.init(content: content, style: style))

                // Continue after the match
                remaining = String(remaining[earliest.range.upperBound...])
            } else {
                // No more matches
                result.append(.init(content: remaining, style: .normal))
                break
            }
        }

        return result
    }
}
