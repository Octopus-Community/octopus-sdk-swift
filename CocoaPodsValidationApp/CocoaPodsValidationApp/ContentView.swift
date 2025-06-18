//
//  ContentView.swift
//  CocoaPodsValidationApp
//
//  Created by Djavan Bertrand on 04/06/2025.
//

import SwiftUI
import Octopus
import OctopusUI

struct ContentView: View {
    let octopus = try! OctopusSDK(apiKey: "SECRET")
    var body: some View {
        OctopusHomeScreen(octopus: octopus)
    }
}
#Preview {
    ContentView()
}
