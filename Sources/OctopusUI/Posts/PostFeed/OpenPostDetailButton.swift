//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct OpenPostDetailButton<Content: View>: View {
    let post: DisplayablePost
    let displayPostDetail: (String) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: {
            if post.canBeOpened {
                displayPostDetail(post.uuid)
            }
        }) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .preventScrollViewConflict()
    }
}

fileprivate extension View {
    /// This function prevent any tap conflict on a Button that can occurs when a Button is inside a ScrollView
    /// presented with a sheet on iOS 18.
    /// In that case, adding a simultaneous TapGesture seems to remove the bug.
    func preventScrollViewConflict() -> some View {
        self
            .modify {
                if #available(iOS 26, *) {
                    $0
                } else {
                    if #available(iOS 18, *) {
                        $0.simultaneousGesture(TapGesture())
                    } else {
                        $0
                    }
                }
            }
    }
}
