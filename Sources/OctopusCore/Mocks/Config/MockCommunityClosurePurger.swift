//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

#if DEBUG
/// Counts the purges instead of deleting anything.
final class MockCommunityClosurePurger: CommunityClosurePurger, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.communityClosurePurger

    private let lock = NSLock()
    private var _purgeCount = 0
    var purgeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _purgeCount
    }

    func purge() async throws {
        increment()
    }

    private func increment() {
        lock.lock()
        defer { lock.unlock() }
        _purgeCount += 1
    }
}
#endif
