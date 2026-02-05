//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

extension Int32 {
    init?(safeCast value: Double) {
        guard value.isFinite,
              value >= Double(Int32.min),
              value <= Double(Int32.max)
        else {
            return nil
        }
        self = Int32(value)
    }
}
