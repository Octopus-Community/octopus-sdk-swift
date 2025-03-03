//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing

func expectWithTimeout(timeout: TimeInterval = 0.5, _ block: @autoclosure () throws -> Bool) async throws {
    var elapsedTime: TimeInterval = 0
    let steps = 0.005
    while !(try block()) {
        guard elapsedTime < timeout else {
            #expect(Bool(false), "Timed out")
            return
        }
        try await Task.sleep(nanoseconds: .secondsToNano(steps))
        elapsedTime += steps
    }
}
