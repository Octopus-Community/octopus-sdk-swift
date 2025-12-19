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

    @ViewBuilder
    func toolbar<LeadingView: View, TrailingView: View, PreTrailingView: View>(
        leading: LeadingView, preTrailing: PreTrailingView?, trailing: TrailingView,
        leadingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        preTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        trailingSharedBackgroundVisibility: Compat.Visibility = .automatic
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }
                .sharedBackgroundVisibility(leadingSharedBackgroundVisibility.usableValue)

                if let preTrailing {
                    ToolbarItem(placement: .topBarTrailing) {
                        preTrailing
                    }
                    .sharedBackgroundVisibility(preTrailingSharedBackgroundVisibility.usableValue)

                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    trailing
                }
                .sharedBackgroundVisibility(trailingSharedBackgroundVisibility.usableValue)
            }
        } else if let preTrailing {
            self.navigationBarItems(leading: leading, trailing: HStack { preTrailing; trailing })
        } else {
            self.navigationBarItems(leading: leading, trailing: trailing)
        }
#else
        if let preTrailing {
            self.navigationBarItems(leading: leading, trailing: HStack { preTrailing; trailing })
        } else {
            self.navigationBarItems(leading: leading, trailing: trailing)
        }
#endif
    }
}
