//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct ScenariosView: View {
    @State var isDisplayed = false

    var body: some View {
        List {
            SheetCell()
            CustomThemeCell()
            SSOCell()
        }
        .listStyle(.plain)
        .navigationBarTitle(Text("Scenarios"), displayMode: .inline)
    }
}
