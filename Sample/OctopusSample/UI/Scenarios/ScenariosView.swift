//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct ScenariosView: View {
    let showFullScreen: (@escaping () -> any View) -> Void
    let showInSheet: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationView {
            List {
                SheetCell(showInSheet: showInSheet)
                CustomThemeCell(showFullScreen: showFullScreen)
                NotSeenNotificationsCell(showFullScreen: showFullScreen)
                ABTestsCell(showFullScreen: showFullScreen)
                SSOCell(showFullScreen: showFullScreen)
            }
            .listStyle(.plain)
            .navigationBarTitle(Text("Scenarios"), displayMode: .inline)
        }
    }
}
