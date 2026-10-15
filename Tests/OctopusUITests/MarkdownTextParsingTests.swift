//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// The markdown parser of the iOS 13–14 fallback (`MarkdownText`): a link whose URL is invalid is shown as plain
/// text instead of crashing the rendering. Main-actor bound like every SwiftUI `View`.
@MainActor
struct MarkdownTextParsingTests {
    private let markdownText = MarkdownText("")

    private func links(in text: String) -> [URL] {
        markdownText.parse(text: text).compactMap {
            if case let .link(url) = $0.style { return url }
            return nil
        }
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
}
