//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The legal notice shown under the post, comment and reply composers in the implicit consent mode.
///
/// It is never truncated: up to ``maxVisibleLines`` lines of its font it takes its natural height. Beyond that it
/// scrolls in a zone half a line taller (the cut-off line shows there is more, and the scroll indicator flashes on
/// iOS 17+), so a long notice cannot push the composer away. Whatever the font size, the visible notice never
/// exceeds ``maxRelativeHeight`` of the window height: at the largest accessibility sizes, five lines of text would
/// otherwise fill the composer, so the notice scrolls earlier and in a shorter zone. On iOS 13 and 14 the fallback
/// markdown renderer spaces explicit line breaks by 4 pt, so a notice of five lines may scroll slightly early there.
struct ImplicitConsentNotice: View {
    @Environment(\.octopusTheme) private var theme

    /// Markdown of the notice (links, bold, italic; line breaks kept).
    let markdown: String

    /// Lines shown before the notice scrolls.
    static let maxVisibleLines = 5

    /// Largest share of the window height the visible notice may take.
    static let maxRelativeHeight: CGFloat = 0.2

    /// The content and the cap are measured on two different views; a difference below this is measurement noise,
    /// not a reason to scroll.
    private static let measurementTolerance: CGFloat = 1

    @State private var contentHeight: CGFloat = 0
    @State private var maxHeight: CGFloat = 0

    /// Height of the window hosting the notice, `0` until it is known (the screen's height then stands in for it).
    @State private var windowHeight: CGFloat = 0

    private var font: Font { theme.fonts.caption2.weight(.medium) }

    var body: some View {
        // The scroll view only exists once the text is known to overflow the cap: until then (in particular on the
        // very first pass, which lands inside the composer's insertion animation) the notice is a plain text at its
        // natural height, so a short notice looks and animates exactly as it always did.
        Group {
            if Self.scrolls(contentHeight: contentHeight, maxHeight: maxHeight, windowHeight: windowHeight,
                            fallbackWindowHeight: provisionalWindowHeight) {
                ScrollView { text }
                    .frame(height: Self.scrollingHeight(maxHeight: maxHeight, windowHeight: windowHeight,
                                                        fallbackWindowHeight: provisionalWindowHeight))
                    .modify {
                        if #available(iOS 17, *) {
                            $0.scrollIndicatorsFlash(onAppear: true)
                        } else { $0 }
                    }
            } else {
                text
            }
        }
        .background(linesProbe)
        .readWindowHeight($windowHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var text: some View {
        RichText(markdown)
            .font(font)
            .foregroundColor(theme.colors.gray900)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .readHeight($contentHeight)
    }

    /// Invisible text of ``maxVisibleLines`` lines in the notice's font, measured to get the cap. Measuring it,
    /// rather than computing a line height, keeps the cap right with the theme's fonts at every Dynamic Type size.
    private var linesProbe: some View {
        Text(verbatim: Array(repeating: "A", count: Self.maxVisibleLines).joined(separator: "\n"))
            .font(font)
            .fixedSize()
            .readHeight($maxHeight)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Height of the notice once it scrolls: the cap plus half a line, so the cut-off line shows that there is more,
    /// but never more than ``maxRelativeHeight`` of the window. While the window height is unknown (zero),
    /// `fallbackWindowHeight` stands in for it, so the first pass is never uncapped.
    static func scrollingHeight(maxHeight: CGFloat, windowHeight: CGFloat, fallbackWindowHeight: CGFloat) -> CGFloat {
        let lineCapped = maxHeight + maxHeight / CGFloat(2 * maxVisibleLines)
        let window = resolvedWindowHeight(measured: windowHeight, fallback: fallbackWindowHeight)
        guard window > 0 else { return lineCapped }
        return min(lineCapped, window * maxRelativeHeight)
    }

    /// Whether the content is taller than the line cap or than the relative cap, and so has to scroll. `false` until
    /// the line cap is measured. While the window height is unknown (zero), `fallbackWindowHeight` stands in for it.
    static func scrolls(contentHeight: CGFloat, maxHeight: CGFloat, windowHeight: CGFloat,
                        fallbackWindowHeight: CGFloat) -> Bool {
        guard maxHeight > 0 else { return false }
        let window = resolvedWindowHeight(measured: windowHeight, fallback: fallbackWindowHeight)
        let limit = window > 0 ? min(maxHeight, window * maxRelativeHeight) : maxHeight
        return contentHeight > limit + measurementTolerance
    }
}
