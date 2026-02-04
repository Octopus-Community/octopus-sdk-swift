//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct RichText: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var urlOpener: URLOpener

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if #available(iOS 15, *) {
            Text((try? AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
            .tint(theme.colors.link)
            .textSelection(.enabled)
            .environment(\.openURL, OpenURLAction { url in
                urlOpener.open(url: url)
                return .handled
            })
        } else {
            MarkdownText(text)
        }
    }
}

private struct MarkdownText: View {
    @EnvironmentObject private var urlOpener: URLOpener

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
            var earliestMatch: (pattern: Pattern, match: NSTextCheckingResult, range: Range<String.Index>)? = nil

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
