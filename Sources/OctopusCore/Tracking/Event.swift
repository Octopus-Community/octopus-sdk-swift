//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import os

/// A tracking event
struct Event {
    /// Unique id of this event
    let uuid: String
    /// Date at which this event has been generated
    let date: Date
    /// App session during which this event has been generated
    let appSessionId: String?
    /// UI session during which this event has been generated
    let uiSessionId: String?
    /// Nb of attempts to send this event to the backend
    let sendingAttempts: Int16
    /// Content of this event (i.e. type of event with its params)
    let content: Content

    /// Type of events
    enum Content {
        /// Triggered when the app is in foreground
        case enteringApp(firstSession: Bool)
        /// Triggered when the app moves to background
        case leavingApp(startDate: Date, endDate: Date, firstSession: Bool)
        /// Triggered when the Octopus UI is displayed
        case enteringUI(firstSession: Bool)
        /// Triggered when the Octopus UI is displayed not displayed anymore
        case leavingUI(startDate: Date, endDate: Date, firstSession: Bool)
        /// Triggered when a post has been opened. Success is the result of the first getObject
        case postOpened(origin: PostOpenedOrigin, success: Bool)
        /// Triggered when a user opens the client object from a bridge post
        case openClientObjectFromBridge
        /// Triggered when the "View original" or "View translation" button is tapped
        case translationButtonHit(translationDisplayed: Bool)
        /// Triggered when a video has been played. Watch Time can be more than duration if the video has been played
        /// more than once fully.
        case videoPlayed(objectId: String, videoId: String, watchTime: TimeInterval, duration: TimeInterval)
        /// Triggered when the user taps on the button of a post with CTA
        case ctaPostButtonHit(objectId: String)
        /// Custom event, set by the client
        case custom(CustomEvent)
    }

    enum PostOpenedOrigin {
        case clientApp
        case sdk(hasFeaturedComment: Bool)
    }

    init(date: Date, appSessionId: String?, uiSessionId: String?, content: Content) {
        self.uuid = UUID().uuidString
        self.date = date
        self.appSessionId = appSessionId
        self.uiSessionId = uiSessionId
        self.sendingAttempts = 0
        self.content = content
    }
}

extension Event: CustomStringConvertible {
    var description: String {
        return "Evt \(uuid): \n" +
        "    date: \(date)\n" +
        "    appSessionId: \(appSessionId ?? "nil")\n" +
        "    uiSessionId: \(uiSessionId ?? "nil")\n" +
        "    content: \n\(content.description)\n" +
        "    sendingAttempts: \(sendingAttempts)\n"
    }
}

extension Event.Content: CustomStringConvertible {
    var description: String {
        let name: String
        let extra: String?
        switch self {
        case let .enteringApp(firstSession):
            name = "enteringApp"
            extra = "        firstSession: \(firstSession)"
        case let .leavingApp(startDate, endDate, firstSession):
            name = "leavingApp"
            extra = "        startDate: \(startDate)\n" +
                    "        endDate: \(endDate)\n" +
                    "        firstSession: \(firstSession)"
        case let .enteringUI(firstSession):
            name = "enteringUI"
            extra = "        firstSession: \(firstSession)"
        case let .leavingUI(startDate, endDate, firstSession):
            name = "leavingUI"
            extra = "        startDate: \(startDate)\n" +
                    "        endDate: \(endDate)\n" +
                    "        firstSession: \(firstSession)"
        case let .postOpened(origin, success):
            name = "postOpened"
            extra = "        origin: \(origin)\n" +
                    "        success: \(success)"
        case .openClientObjectFromBridge:
            name = "openClientObjectFromBridge"
            extra = nil
        case let .translationButtonHit(viewTranslated):
            name = "translationButtonHit"
            extra = "        viewTranslated: \(viewTranslated)"
        case let .videoPlayed(objectId, videoId, watchTime, duration):
            name = "videoPlayed"
            extra = "        objectId: \(objectId)\n" +
                    "        videoId: \(videoId)\n" +
                    "        watchTime: \(Int(watchTime))\n" +
                    "        duration: \(Int(duration))"
        case let .ctaPostButtonHit(objectId):
            name = "ctaPostButtonHit"
            extra = "        objectId: \(objectId)"
        case let .custom(customEvent):
            name = "custom"
            extra = "        name: \(customEvent.name)\n" +
                    "        properties: \(customEvent.properties.mapValues { $0.value })"
        }
        let kind = "        kind:\(name)"
        if let extra = extra {
            return "\(kind)\n\(extra)"
        } else {
            return kind
        }
    }
}

extension Event {
    init?(from entity: EventEntity) {
        uuid = entity.uuid
        date = Date(timeIntervalSince1970: entity.timestamp)
        appSessionId = entity.appSessionId
        uiSessionId = entity.uiSessionId
        sendingAttempts = entity.sendingAttempts
        let optionalContent: Content? = switch entity {
        case let evt as EnteringAppEventEntity:
                .enteringApp(firstSession: evt.firstSession)
        case let evt as LeavingAppEventEntity:
                .leavingApp(startDate: Date(timeIntervalSince1970: evt.startTimestamp),
                            endDate: Date(timeIntervalSince1970: evt.endTimestamp),
                            firstSession: evt.firstSession)
        case let evt as EnteringUIEventEntity:
                .enteringUI(firstSession: evt.firstSession)
        case let evt as LeavingUIEventEntity:
                .leavingUI(startDate: Date(timeIntervalSince1970: evt.startTimestamp),
                           endDate: Date(timeIntervalSince1970: evt.endTimestamp),
                           firstSession: evt.firstSession)
        case let evt as PostOpenedEventEntity:
            if let origin = Event.PostOpenedOrigin(from: evt) {
                .postOpened(origin: origin, success: evt.success)
            } else {
                nil
            }
        case is OpenClientObjectFromBridgeEventEntity:
                .openClientObjectFromBridge
        case let evt as TranslationButtonHitEventEntity:
                .translationButtonHit(translationDisplayed: evt.translationDisplayed)
        case let evt as VideoPlayedEventEntity:
                .videoPlayed(objectId: evt.octoObjectId,
                             videoId: evt.videoId,
                             watchTime: evt.watchTime,
                             duration: evt.duration
                )
        case let evt as CtaPostButtonHitEntity:
                .ctaPostButtonHit(objectId: evt.octoObjectId)
        case let evt as CustomEventEntity:
                .custom(CustomEvent(
                    name: evt.name,
                    properties: Dictionary(evt.properties.map { ($0.name, CustomEvent.PropertyValue(value: $0.value)) },
                                           uniquingKeysWith: { first, _ in first }))
                )
        default: nil
        }
        guard let optionalContent else {
            if #available(iOS 14, *) { Logger.tracking.error("Dev error: \(type(of: entity)) not translated to Event.Content") }
            return nil
        }
        self.content = optionalContent
    }
}
