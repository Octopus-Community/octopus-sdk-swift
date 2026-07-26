//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Presents the explicit terms-acceptance ``TermsConsentSheet`` as a bottom sheet over the editor.
/// Renders nothing for `.implicit` (the caller only flips `isPresented` in explicit modes). Dismissal
/// by swipe / tap outside just closes it (nothing published); tapping the action button calls
/// `onAccept` (record acceptance + resume publishing) and closes the sheet.
private struct TermsConsentSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let mode: TermsAcceptanceMode
    let contribution: ConsentContribution
    let termsUrl: URL
    let privacyUrl: URL
    let rulesUrl: URL
    let onAccept: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if mode.isExplicit {
                TermsConsentSheet(
                    mode: mode,
                    contribution: contribution,
                    termsUrl: termsUrl,
                    privacyUrl: privacyUrl,
                    rulesUrl: rulesUrl,
                    onAccept: {
                        isPresented = false
                        onAccept()
                    })
                .sizedSheet()
            } else {
                EmptyView()
            }
        }
    }
}

extension View {
    func termsConsentSheet(
        isPresented: Binding<Bool>,
        mode: TermsAcceptanceMode,
        contribution: ConsentContribution,
        termsUrl: URL,
        privacyUrl: URL,
        rulesUrl: URL,
        onAccept: @escaping () -> Void
    ) -> some View {
        modifier(TermsConsentSheetModifier(
            isPresented: isPresented,
            mode: mode,
            contribution: contribution,
            termsUrl: termsUrl,
            privacyUrl: privacyUrl,
            rulesUrl: rulesUrl,
            onAccept: onAccept))
    }
}
