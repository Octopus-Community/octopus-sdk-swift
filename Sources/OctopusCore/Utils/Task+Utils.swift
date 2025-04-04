//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum TaskUtils {
    static func wait(for block: @autoclosure () throws -> Bool, timeout: TimeInterval = 0.5) async throws {
        var elapsedTime: TimeInterval = 0
        let steps = 0.005
        while !(try block()) {
            guard elapsedTime < timeout else {
                throw InternalError.timeout
            }
            try await Task.sleep(nanoseconds: UInt64(steps * 1_000_000_000))
            elapsedTime += steps
        }
    }
}
