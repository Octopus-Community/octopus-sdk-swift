//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A simple seedable random number generator (Xorshift64*)
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Ensure state is never zero
        self.state = seed == 0 ? 0xdeadbeef : seed
    }

    mutating func next() -> UInt64 {
        // Xorshift64* algorithm
        var x = state
        x ^= x >> 12
        x ^= x << 25
        x ^= x >> 27
        state = x
        return x &* 2685821657736338717
    }
}

/// Shuffle with a given seed
extension Array {
    func shuffled(seed: UInt64) -> [Element] {
        var generator = SeededGenerator(seed: seed)
        return self.shuffled(using: &generator)
    }
}
