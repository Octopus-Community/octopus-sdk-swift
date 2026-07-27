//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Design-system line height for **body-2 *content* (reading) text** — post body, comment/reply
/// body and catch phrases (the surfaces Android tags with its content `lineHeight` token).
///
/// The Figma design system specs body-2 content as SF Pro Text 16px with a **24px line height**
/// — a **1.5 ratio** relative to the font size (also Android's ratio, `fontSize * 1.5`).
///
/// The line height is expressed as a **ratio**, not a fixed 24pt, so it scales with Dynamic Type:
/// a fixed 24pt would clip/overlap once the user's accessibility font size pushes the natural line
/// height past 24pt. Concretely, at a 28pt font the natural line height is ~33pt — a fixed 24pt
/// would overlap; `1.5 × fontSize` gives 42pt and stays clear.
///
/// - On **iOS 26+**: the native `lineHeight(.multiple(factor: 1.5))` modifier. `.multiple(factor:)`
///   is relative to the font size, so it hits 24pt at the default 16pt and scales with Dynamic Type.
/// - On **iOS < 26**: no absolute line-height API, so we approximate with a `lineSpacing` computed
///   from the Dynamic-Type-scaled font size (`fontSize * 1.5 − naturalLineHeight`), which also scales.
enum BodyContentLineHeight {
    /// Design-system line-height ratio: 24px line height over a 16px font (relative to font size).
    static let ratio: CGFloat = 24.0 / 16.0
    /// Base font size of the body-2 style (Figma: 16px). Used only for the pre-iOS 26 fallback.
    static let baseFontSize: CGFloat = 16
}

private struct BodyContentLineHeightModifier: ViewModifier {
    // Dynamic-Type-scaled body-2 font size (matches `OctopusTheme.Fonts.body2` built with
    // `scaledValue(for: 16)`); used by the pre-iOS 26 fallback so its lineSpacing scales too.
    @Compat.ScaledMetric(relativeTo: .body) private var fontSize: CGFloat = BodyContentLineHeight.baseFontSize

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.lineHeight(.multiple(factor: BodyContentLineHeight.ratio))
        } else {
            let targetLineHeight = fontSize * BodyContentLineHeight.ratio
            let naturalLineHeight = UIFont.systemFont(ofSize: fontSize).lineHeight
            content.lineSpacing(max(0, targetLineHeight - naturalLineHeight))
        }
    }
}

extension View {
    /// Applies the design-system body-2 *content* line height (24px at 16px, scaling with Dynamic
    /// Type). See `BodyContentLineHeight`.
    func octopusBodyContentLineHeight() -> some View {
        modifier(BodyContentLineHeightModifier())
    }
}
