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
    @State private var animatedSelectedTab: Int = 0

    @State private var width: CGFloat = 0

    let index = 0

    var body: some View {
        VStack(alignment: .centeredAlignment, spacing: 18) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    Text(self.tabs[index], bundle: .module)
                        .font(theme.fonts.body2.weight(.medium))
                        .foregroundColor(selectedTab == index ? theme.colors.primary : theme.colors.gray700)
                        .onTapGesture {
                            selectedTab = index
                        }
                        .contentShape(Rectangle())
                        .frame(width: itemWidth)
                        .modify {
                            if animatedSelectedTab == index {
                                $0.alignmentGuide(.centeredAlignment, computeValue: { d in d[HorizontalAlignment.center] })
                            } else {
                                $0
                            }
                        }
                }
                if tabs.count == 1 {
                    Spacer()
                }
            }
            Rectangle()
                .frame(width: itemWidth, height: 2)
                .foregroundColor(theme.colors.primary)
                .alignmentGuide(.centeredAlignment, computeValue: { d in d[HorizontalAlignment.center] })
        }
        .frame(maxWidth: .infinity)
        .background(GeometryReader { geometry in
            Color.clear
                .onValueChanged(of: geometry.size.width) { width in
                    updateWidth(computedWidth: width, screenWidth: UIScreen.main.bounds.width)
                }
                .onAppear {
                    updateWidth(computedWidth: geometry.size.width, screenWidth: UIScreen.main.bounds.width)
                }
        })
        .onAppear {
            animatedSelectedTab = selectedTab
        }
        .onValueChanged(of: selectedTab) { selectedTab in
            withAnimation(.spring(duration: 0.2)) {
                animatedSelectedTab = selectedTab
            }
        }
        .padding(.top, 16)
    }

    private func updateWidth(computedWidth: CGFloat, screenWidth: CGFloat) {
        let window = UIApplication.shared.windows.first
        let leftPadding = window?.safeAreaInsets.left ?? 0
        let rightPadding = window?.safeAreaInsets.right ?? 0
        // +1 to avoid a bug when going from portrait to landscape and back to portrait where the width was still
        // very large (the size of the landscape).
        let horizontalPadding = leftPadding + rightPadding + 1
        self.width = min(computedWidth, screenWidth - horizontalPadding)
    }

    private var tabCountForSizing: Int {
        guard let tabCount else { return tabs.count }
        // avoid tabs being bigger than their max size
        guard tabCount > tabs.count else { return tabs.count }
        return tabCount
    }

    private var itemWidth: CGFloat {
        return max(width / CGFloat(tabCountForSizing), 100)
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
