//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @ViewBuilder
    func toolbar<LeadingView: View, CenteredView: View, TrailingView: View, PreTrailingView: View>(
        leading: LeadingView,
        preTrailing: PreTrailingView = EmptyView(),
        trailing: TrailingView,
        centered: CenteredView = EmptyView(),
        leadingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        preTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        trailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        centeredVisibility: Compat.Visibility = .automatic
    ) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), GlassEffect.isAvailable {
            // From iOS 27, the bar proposes a side item less width than it needs, which truncates a text label
            // ("Publish" became "Pub…"). The side items keep their ideal width instead: the title gives way.
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                        .fixedSize(horizontal: true, vertical: false)
                }
                .sharedBackgroundVisibility(leadingSharedBackgroundVisibility.usableValue)

                ToolbarItem(placement: .principal) {
                    if centeredVisibility != .hidden {
                        centered
                    } else {
                        Color.clear
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    preTrailing
                        .fixedSize(horizontal: true, vertical: false)
                }
                .sharedBackgroundVisibility(preTrailingSharedBackgroundVisibility.usableValue)

                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    trailing
                        .fixedSize(horizontal: true, vertical: false)
                }
                .sharedBackgroundVisibility(trailingSharedBackgroundVisibility.usableValue)
            }
            .navigationBarTitleDisplayMode(.inline)
        } else if #available(iOS 14.0, *) {
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }

                ToolbarItem(placement: .principal) {
                    if centeredVisibility != .hidden {
                        centered
                    } else {
                        Color.clear
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        preTrailing
                        trailing
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        } else {
            self.navigationBarItems(leading: leading, trailing: trailing)
        }
#else
        if #available(iOS 14.0, *) {
            self.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leading
                }

                ToolbarItem(placement: .principal) {
                    if centeredVisibility != .hidden {
                        centered
                    } else {
                        Color.clear
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        preTrailing
                        trailing
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        } else {
            self.navigationBarItems(leading: leading, trailing: trailing)
        }
#endif
    }
}
