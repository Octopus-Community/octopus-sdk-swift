//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import Testing
@testable import OctopusUI

/// What the entry screens rely on to hand their views a theme that follows the text size:
/// `environmentThemeSizedForTextSize()`.
@Suite(.serialized)
@MainActor
struct OctopusThemeEnvironmentTests {
    private let courier = Font.custom("Courier New", size: 26)

    @Test func defaultFontsAreSizedForTheTextSizeOfTheEnvironment() async throws {
        let recorder = FontsRecorder()
        let theme = OctopusTheme(fonts: .init(title1: courier))

        try await renderInWindow(
            FontsProbe(recorder: recorder)
                .environmentThemeSizedForTextSize()
                .environment(\.octopusTheme, theme)
                .environment(\.sizeCategory, .accessibilityLarge),
            until: { recorder.fonts != nil })

        #expect(recorder.fonts?.body1 == theme.fonts.resized(for: .accessibilityLarge).body1)
        #expect(recorder.fonts?.title1 == courier)
    }

    // The bug it fixes: a theme created once by the host, and the text size changing while the views are displayed.
    @Test func defaultFontsFollowATextSizeChangeOfATheme() async throws {
        let recorder = FontsRecorder()
        let textSize = TextSize(.large)
        let theme = OctopusTheme(fonts: .init(title1: courier))
        let expected = theme.fonts.resized(for: .accessibilityExtraLarge)

        try await renderInWindow(
            TextSizeHost(textSize: textSize, theme: theme, recorder: recorder),
            until: { recorder.fonts != nil },
            andThen: {
                textSize.value = .accessibilityExtraLarge
                try await waitUntil { recorder.fonts?.body1 == expected.body1 }
            })

        #expect(recorder.fonts?.body1 == expected.body1)
        #expect(recorder.fonts?.title1 == courier)
    }
}

@MainActor
private final class FontsRecorder {
    var fonts: OctopusTheme.Fonts?
}

@MainActor
private final class TextSize: ObservableObject {
    @Published var value: ContentSizeCategory

    init(_ value: ContentSizeCategory) {
        self.value = value
    }
}

/// Reads the theme the way the SDK's views do.
private struct FontsProbe: View {
    @Environment(\.octopusTheme) private var theme

    let recorder: FontsRecorder

    var body: some View {
        recorder.fonts = theme.fonts
        return Color.clear
    }
}

/// A host keeping the same theme while its text size changes.
private struct TextSizeHost: View {
    @ObservedObject var textSize: TextSize
    let theme: OctopusTheme
    let recorder: FontsRecorder

    var body: some View {
        FontsProbe(recorder: recorder)
            .environmentThemeSizedForTextSize()
            .environment(\.octopusTheme, theme)
            .environment(\.sizeCategory, textSize.value)
    }
}
