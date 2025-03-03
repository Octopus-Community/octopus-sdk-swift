//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct SSOScenariosView: View {
    @ObservedObject var model: SampleModel
    
    var body: some View {
        VStack(alignment: .leading) {
            List {
                WithoutAppManagedFieldsCell(model: model)
                WithAllAppManagedFieldsCell(model: model)

                // Hybrid case is not handled yet
            }
            Text("In order to test this, you must set your API key to OCTOPUS_SSO_API_KEY in secrets.xcconfig.")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding()
        }
        .listStyle(.plain)
        .navigationBarTitle(Text("SSO Scenarios"), displayMode: .inline)
    }
}
