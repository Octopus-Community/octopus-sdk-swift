//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func toolbar<LeadingView: View, TrailingView: View>(
        leading: LeadingView, trailing: TrailingView,
        leadingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        trailingSharedBackgroundVisibility: Compat.Visibility = .automatic
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }
                .sharedBackgroundVisibility(leadingSharedBackgroundVisibility.usableValue)

                ToolbarItem(placement: .topBarTrailing) {
                    trailing
                }
                .sharedBackgroundVisibility(trailingSharedBackgroundVisibility.usableValue)
            }
        } else {
            self.navigationBarItems(leading: leading, trailing: trailing)
        }
#else
        self.navigationBarItems(leading: leading, trailing: trailing)
#endif
    }
}
