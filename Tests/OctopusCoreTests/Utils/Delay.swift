//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

/// Delay a bit the next execution.
/// This can be handy in the tests if some reactive things are post on a different queue.
/// - Note: this is just a wrapper around Task.sleep that sleeps for a static amount of time.
///         If possible, expectations should be prefered but there is no expectation in Swift Testing
func delay() async throws {
    try await Task.sleep(nanoseconds: .secondsToNano(0.01))
}

extension UInt64 {
    static func secondsToNano(_ seconds: Double) -> UInt64 {
        return UInt64(seconds * 1_000_000_000)
    }
}
