//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that shows how to add the `displayClientObjectCallback` to the SDK to be informed when the user tapped
/// on a button that should display one of your objects
class BridgeToClientObjectViewModel: ObservableObject {

    @Published var recipePushed: Recipe?
    @Published var recipePresented: Recipe?
    @Published var displayOctopusAsFullScreenModal = false
    @Published var displayOctopusAsSheet = false
    @Published var octopusPostId: String? {
        didSet {
            guard octopusPostId != nil else { return }
            displayOctopusAsSheet = true
        }
    }

    @Published private(set) var octopus: OctopusSDK?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)
    }

    func configureSDK() {
        // Set the callback that will be called when the user tapped on a button that should display one of your objects
        octopusSDKProvider.octopus?.set(displayClientObjectCallback: { [weak self] objectId in
            guard let self else { return }
            // we only display the stableRecipe
            guard objectId == stableRecipe.id else { throw NSError(domain: "", code: 0) }
            let recipe = stableRecipe
            if recipePushed != nil {
                recipePushed = recipe // be sure that the recipe displayed is the one we want
                displayOctopusAsSheet = false // be sure to hide Octopus
            } else {
                // we are on the BridgeToClientView so display the recipe modally
                recipePresented = recipe
            }
        })
    }
}
