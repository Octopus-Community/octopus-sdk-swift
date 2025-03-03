//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct CustomSegmentedControl: View {
    @Environment(\.octopusTheme) private var theme

    let tabs: [LocalizedStringKey]
    // if set, it will be used to fake the number of tabs (used to size the tabs)
    let tabCount: Int?
    @Binding var selectedTab: Int

    @State private var width: CGFloat = 0

    let index = 0

    var body: some View {
        VStack(alignment: .centeredAlignment, spacing: 18) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    Group {
                        if selectedTab == index {
                            Text(self.tabs[index], bundle: .module)
                                .foregroundColor(theme.colors.accent)
                                .alignmentGuide(.centeredAlignment, computeValue: { d in d[HorizontalAlignment.center] })
                        } else {
                            Text(self.tabs[index], bundle: .module)
                                .foregroundColor(theme.colors.accent)
                                .onTapGesture {
                                    withAnimation {
                                        selectedTab = index
                                    }
                                }
                        }
                    }
                    .font(theme.fonts.body2.weight(.medium))
                    .frame(width: itemWidth)
                }
                Spacer()
            }
            Rectangle()
                .frame(width: itemWidth, height: 2)
                .foregroundColor(theme.colors.accent)
                .alignmentGuide(.centeredAlignment, computeValue: { d in d[HorizontalAlignment.center] })
        }
        .frame(maxWidth: .infinity)
        .background(GeometryReader { geometry in
            Color.clear
                .onValueChanged(of: geometry.size.width) { width in
                    self.width = width
                }
                .onAppear {
                    self.width = geometry.size.width
                }
        })
    }

    private var tabCountForSizing: Int {
        guard let tabCount else { return tabs.count }
        // avoid tabs being bigger than their max size
        guard tabCount > tabs.count else { return tabs.count }
        return tabCount
    }

    private var itemWidth: CGFloat {
        max(width / (CGFloat(tabCountForSizing) + 0.1), 100) // +0.1 to avoid overlaps
    }
}

private extension HorizontalAlignment {
    private enum CenteredAlignment : AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat {
            return d[HorizontalAlignment.center]
        }
    }
    static let centeredAlignment = HorizontalAlignment(CenteredAlignment.self)
}
