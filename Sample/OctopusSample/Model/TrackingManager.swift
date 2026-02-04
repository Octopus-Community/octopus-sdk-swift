//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// This class is a singleton that shows how to get SDK event in order to inject them in your own tracking/analytics
/// tools
class TrackingManager {
    static let instance = TrackingManager()

    @Published private(set) var events: [OctopusEvent] = []

    private var storage = [AnyCancellable]()

    private init() { }

    /// Function called when the Octopus SDK is created.
    func set(octopus: OctopusSDK) {
        storage = []
        events = []
        octopus.eventPublisher.sink { [unowned self] event in
            // Store this new event in a list, just to display it in the Events Scenario
            events.append(event)

            // here you convert Octopus Events into events for your analytics tool
            // for example, for Firebase:
            //
            // if case let .postCreated(context) = event {
            //     Analytics.logEvent("post_created", parameters: [
            //         "topic": context.topicId,
            //         "text_length": context.textLength,
            //         "has_poll": context.content.contains(.poll),
            //         "has_image": context.content.contains(.image)
            //     ])
            // }
        }.store(in: &storage)
    }
}
