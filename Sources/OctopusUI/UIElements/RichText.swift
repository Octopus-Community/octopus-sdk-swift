//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct RichText: View {
    @Environment(\.octopusTheme) private var theme
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
        } else {
            MarkdownText(text)
        }
    }
}

private struct MarkdownText: View {
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
                        UIApplication.shared.open(links[0])
                    }
                } else {
                    fullText
                }
            }
    }

    func parse(text: String) -> [MarkdownPart] {
        var result: [MarkdownPart] = []
        var remaining = text

        let patterns: [(pattern: String, builder: (String) -> MarkdownStyle)] = [
            (pattern: "\\*\\*(.+?)\\*\\*", builder: { (text: String) -> MarkdownStyle in .bold }),
            (pattern: "__(.+?)__", builder: { (text: String) -> MarkdownStyle in .bold }),
            (pattern: "\\*(.+?)\\*", builder: { (text: String) -> MarkdownStyle in .italic }),
            (pattern: "_(.+?)_", builder: { (text: String) -> MarkdownStyle in .italic }),
            (pattern: "(https?://[\\w./?=&%-]+|www\\.[\\w./?=&%-]+)", builder: { (match: String) -> MarkdownStyle in
                let prefix = match.hasPrefix("http") ? "" : "https://"
                return .link(URL(string: prefix + match)!)
            })
        ]

        while !remaining.isEmpty {
            var matched = false

            for (pattern, styleBuilder) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: remaining, range: NSRange(location: 0, length: remaining.utf16.count)),
                   let fullRange = Range(match.range(at: 0), in: remaining),
                   let contentRange = match.numberOfRanges > 1 ? Range(match.range(at: 1), in: remaining) : fullRange {

                    let before = String(remaining[..<fullRange.lowerBound])
                    if !before.isEmpty {
                        result.append(.init(content: before, style: .normal))
                    }

                    let content = String(remaining[contentRange])
                    result.append(.init(content: content, style: styleBuilder(content)))

                    remaining = String(remaining[fullRange.upperBound...])
                    matched = true
                    break
                }
            }

            if !matched {
                result.append(.init(content: remaining, style: .normal))
                break
            }
        }

        return result
    }
}
