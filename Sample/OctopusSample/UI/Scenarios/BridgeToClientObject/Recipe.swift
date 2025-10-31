//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import Octopus

/// A recipe. This is considered as the `object` of your app.
struct Recipe: Equatable {
    enum Image: Equatable {
        case local(ImageResource)
        case remote(URL)
    }
    let id: String
    let title: String
    let text: String
    let topicName: String?
    let img: Image?
    let cta: String
    let octopusCatchPhrase: String
    let octopusViewClientObjectButtonText: String?

    func toClientPost(topics: [Topic] = []) -> ClientPost {
        // convert the image into an SDK Attachement
        let attachment: ClientPost.Attachment? = switch img {
        case let .local(imgResource):
                .localImage(UIImage(resource: imgResource).jpegData(compressionQuality: 1.0)!)
        case let .remote(url):
                .distantImage(url)
        case .none: nil
        }

        // Example of how to use the topics API: match the topic name to get the topic id
        let topicId: String? = if let topicName {
            topics.first(where: { $0.name == topicName })?.id
        } else { nil }

        let signature: String? = switch SDKConfigManager.instance.sdkConfig?.authKind {
        case .sso: try? TokenProvider().getBridgeSignature()
        default: nil
        }

        return ClientPost(
            clientObjectId: id, // this will be used to link your Object to our post.
            topicId: topicId,
            text: title,
            catchPhrase: octopusCatchPhrase,
            attachment: attachment,
            viewClientObjectButtonText: octopusViewClientObjectButtonText,
            // you should use a signature if your community configuration requires it. We recommand configuring
            // your community to require a signature for security reasons.
            // An example of how the signature might be constructed is available in `TokenProvider` (without the
            // need of the `sub` info in the token), but it is safer if it is your backend that provides the
            // signature.
            signature: signature
        )
    }
}

let stableRecipe = Recipe(
    id: "recipe-1",
    title: "The perfects Cannelés (Bordeaux specialty)",
    text: """
    Is it the first time?
    Before using for the first time, it is advisable to "burn" the Canelés moulds.

    Preheat the oven to 200°C. Grease the moulds and put them in the oven for one hour. Grease them a second time.
    Grease residue can be removed with a cloth.

    For 10 Canelés:

    1/2 liter of milk
    2 egg yolks
    2 vanilla pods
    2 whole eggs
    250 g of sugar
    50 g of butter
    125 g of flour
    50 ml of rum

    The steps (in two times)

    The day before
    Boil the milk and let the vanilla pods infuse
    Mix the sugar and flour
    Add the egg yolks and mix
    Mix the vanilla milk with this preparation
    Mix in the butter and rum
    Let it rest in a cool place

    The day after
    Preheat the oven to thermostat 7 (220 °C)
    Mix the mixture well
    Wipe and grease the moulds with butter (or vegetable matter)
    Place them on a baking sheet
    Pour the liquid dough into the moulds
    Bake for about 1 hour: 1/4 hour at 220 °C and 3/4 hour at 160 °C
    Turn out while hot and let cool
    """,
    topicName: nil,
    img: .local(.Scenarios.BridgeToClientObject.caneles),
    cta: "Give your feedbacks",
    octopusCatchPhrase: "Tried the canelés? Tell us how good they were!",
    octopusViewClientObjectButtonText: "Read the recipe")

let newRecipe = Recipe(
    id: UUID().uuidString,
    title: "French macaroons: typical Parisian-style macaron. Sandwich cookie filled with a ganache, buttercream or jam.",
    text: """
    Equipment
        Baking Sheet
        Stand mixer
        Piping bag

    Ingredients
        - For the Cookie
            - 100 g egg whites room temperature 3 large eggs
            - 140 g almond flour 1 1/2 cups
            - 90 g granulated sugar just under 1/2 cup
            - 130 g powdered sugar 1 cup
            - 1 tsp vanilla 5mL
            - 1/4 tsp cream of tartar 800mg

        - For the Buttercream
            - 1 cup unsalted butter softened 226g
            - 5 egg yolks
            - 1/2 cup granulated sugar 100g
            - 1 tsp vanilla
            - 3 tbsp water 30mL
            - 1 pinch salt

    Instructions
    For the Macarons:
    Sift the confectioners sugar and almond flour into a bowl.
    Add the room temperature egg whites into a very clean bowl.
    Using an electric mixer, whisk egg whites. Once they begin to foam add the cream of tartar and then SLOWLY add the granulated sugar.
    Add the food coloring (if desired) and vanilla then mix in. Continue to beat until stiff peaks form.
    Begin folding in the 1/3 of the dry ingredients.
    Be careful to add the remaining dry ingredients and fold gently.
    The final mixture should look like flowing lava, and be able to fall into a figure eight without breaking. Spoon into a piping bag with a medium round piping tip and you’re ready to start piping.
    Pipe one inch dollops onto a baking sheet lined with parchment paper (this should be glued down with dabs of batter). Tap on counter several times to release air bubbles. Allow to sit for about 40 minutes before placing in oven. 
    Bake at 300F for 12-15 minutes, rotate tray after 7 minutes. Allow to cool completely before removing from baking sheet. 

    For the French Buttercream Filling:
    Combine sugar and water in medium saucepan. Heat over low heat while stirring until sugar dissolves. Increase heat to medium- high and bring to a boil
    Put egg yolks in a stand-mixer fitted with a whisk attachment and beat until thick and foamy.
    Cook the sugar and water syrup until it reaches 240 degrees F. Immediately remove from heat. With mixer running, SLOWLY drizzle hot syrup into bowl with yolks.
    Continue mixing until the bottom of the bowl is cool to the touch and the yolk mixture has cooled to room temperature.
    Add in butter one cube at a time allowing each piece to incorporate before adding the next. Add vanilla and salt. Continue mixing until buttercream is smooth and creamy. (About 5-6 minutes.) Add food coloring if desired.

    For Assembly
    Pipe your filling onto the back of half the shells. Form a sandwich and repeat. Macarons should be aged in the fridge for 1-3 days for best results. This allows the filling to soften the shells inside.
    """,
    topicName: "Gourmands",
    img: .remote(URL(string: "https://upload.wikimedia.org/wikipedia/commons/c/cd/Macarons%2C_French_made_mini_cakes.JPG")!),
    cta: "Give your feedbacks",
    octopusCatchPhrase: "Once baked and eaten, tell us what you think.",
    octopusViewClientObjectButtonText: nil)
