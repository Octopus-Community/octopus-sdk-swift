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
            CustomThemeCell(model: model)
            SSOCell(model: model)
        }
    }
}
