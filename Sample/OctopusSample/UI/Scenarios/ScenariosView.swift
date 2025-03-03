//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct ScenariosView: View {
    @ObservedObject var model: SampleModel

    @State var isDisplayed = false

    var body: some View {
        List {
            SheetCell(model: model)
            CustomThemeCell(model: model)
            SSOCell(model: model)
        }
        .listStyle(.plain)
        .navigationBarTitle(Text("Scenarios"), displayMode: .inline)
    }
}
