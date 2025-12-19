//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// An accessible stack view that starts as an HStack
/// then becomes a VStack once the dynamic type size
/// is an accessibility size.
struct AdaptiveAccessibleStack2Contents<HorizontalContent: View, VerticalContent: View>: View {
    var hStackAlignment: VerticalAlignment = .center
    var hStackSpacing: CGFloat?
    var vStackAlignment: HorizontalAlignment = .center
    var vStackSpacing: CGFloat?
    @ViewBuilder let horizontalContent: HorizontalContent
    @ViewBuilder let verticalContent: VerticalContent

    var body: some View {
        if #available(iOS 15.0, *) {
            AdaptiveAccessibleStackDefault(
                horizontalContent: horizontalContent,
                verticalContent: verticalContent,
                hStackAlignment: hStackAlignment,
                hStackSpacing: hStackSpacing,
                vStackAlignment: vStackAlignment,
                vStackSpacing: vStackSpacing)
        } else {
            HStack(alignment: hStackAlignment, spacing: hStackSpacing) { horizontalContent }
        }
    }
}

/// An accessible stack view that starts as an HStack
/// then becomes a VStack once the dynamic type size
/// is an accessibility size.
struct AdaptiveAccessibleStack<Content: View>: View {
    var hStackAlignment: VerticalAlignment = .center
    var hStackSpacing: CGFloat?
    var vStackAlignment: HorizontalAlignment = .center
    var vStackSpacing: CGFloat?
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 15.0, *) {
            AdaptiveAccessibleStackDefault(
                horizontalContent: content,
                verticalContent: content,
                hStackAlignment: hStackAlignment,
                hStackSpacing: hStackSpacing,
                vStackAlignment: vStackAlignment,
                vStackSpacing: vStackSpacing)
        } else {
            HStack(alignment: hStackAlignment, spacing: hStackSpacing) { content }
        }
    }
}

@available(iOS 15.0, *)
private struct AdaptiveAccessibleStackDefault<HorizontalContent: View, VerticalContent: View>: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    let horizontalContent: HorizontalContent
    let verticalContent: VerticalContent
    let hStackAlignment: VerticalAlignment
    let hStackSpacing: CGFloat?
    let vStackAlignment: HorizontalAlignment
    let vStackSpacing: CGFloat?

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: vStackAlignment, spacing: vStackSpacing) { verticalContent }
                .frame(maxWidth: .infinity, alignment: vStackAlignmentAsAlignment)
        } else {
            HStack(alignment: hStackAlignment, spacing: hStackSpacing) { horizontalContent }
        }
    }

    var vStackAlignmentAsAlignment: Alignment {
        switch vStackAlignment {
        case .center: .center
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}
