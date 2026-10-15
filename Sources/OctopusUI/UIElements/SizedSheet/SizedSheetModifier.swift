//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct SizedSheetModifier: ViewModifier {
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modify {
                if #available(iOS 16.4, *) {
                    $0.readHeight($height)
                        .modify {
                            if Self.sizesToContent {
                                $0.presentationDetents([.height(height)])
                            } else { $0 }
                        }
                        .presentationDragIndicator(.visible)
                } else { $0 }
            }
            .modify {
                if #available(iOS 16.4, *) {
                    $0.presentationContentInteraction(.scrolls)
                } else { $0 }
            }
    }
}

extension SizedSheetModifier {
    /// Whether `sizedSheet()` sizes the sheet to its measured content: from iOS 16.4, unless VoiceOver runs.
    /// Otherwise the sheet keeps its full (large) height, so content that can outgrow it must scroll on its own.
    static var sizesToContent: Bool {
        if #available(iOS 16.4, *) {
            return !UIAccessibility.isVoiceOverRunning
        }
        return false
    }
}

extension View {
    func sizedSheet() -> some View {
        self.modifier(SizedSheetModifier())
    }
}
