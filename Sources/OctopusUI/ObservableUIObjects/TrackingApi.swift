//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// Tracking abstraction used by OctopusUI views. Protocol form allows previews and tests
/// to inject a no-op implementation (see `NoopTrackingApi`).
/// Conforms to `Sendable` so an `any TrackingApi` can be stored as an `EnvironmentKey`
/// default without `nonisolated(unsafe)`. All tracking methods are fire-and-forget
/// forwards to repository/event-emitter APIs that are themselves safe to call from any
/// thread (no mutable view-level state touched here), so the conformance is genuine.
protocol TrackingApi: Sendable {
    func trackTranslationButtonHit(translationDisplayed: Bool)
    func trackPostCustomActionButtonHit(postId: String)
    func emit(event: SdkEvent)
}

/// Production implementation backed by an `OctopusSDK`. `@unchecked Sendable` because
/// `OctopusSDK` is an `ObservableObject` (not `Sendable`), but `DefaultTrackingApi` only
/// holds an immutable reference to it and forwards calls to inherently thread-safe
/// repository/event APIs — no mutable state of its own to protect.
final class DefaultTrackingApi: TrackingApi, @unchecked Sendable {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func trackTranslationButtonHit(translationDisplayed: Bool) {
        octopus.core.trackingRepository.trackTranslationButtonHit(translationDisplayed: translationDisplayed)
    }

    func trackPostCustomActionButtonHit(postId: String) {
        octopus.core.trackingRepository.trackCtaPostButtonHit(postId: postId)
    }

    func emit(event: SdkEvent) {
        octopus.core.sdkEventsEmitter.emit(event)
    }
}

/// No-op `TrackingApi` used as the default environment value so previews render without setup.
struct NoopTrackingApi: TrackingApi, Sendable {
    func trackTranslationButtonHit(translationDisplayed: Bool) {}
    func trackPostCustomActionButtonHit(postId: String) {}
    func emit(event: SdkEvent) {}
}
