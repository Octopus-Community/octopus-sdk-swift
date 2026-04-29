//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Abstraction for opening URLs from SDK views. Allows injection of no-op / recording implementations
/// in previews and tests without requiring a full OctopusSDK. `Sendable` so an `any URLOpening`
/// can sit in an `EnvironmentKey` default without `nonisolated(unsafe)`; the production
/// implementation is `@MainActor` (implicitly Sendable) and the no-op is a plain `Sendable` struct.
protocol URLOpening: Sendable {
    @MainActor func open(url: URL)
}

/// No-op `URLOpening` used as the default environment value (so previews render without any setup).
struct NoopURLOpener: URLOpening, Sendable {
    @MainActor func open(url: URL) {}
}
