//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockApiKeyService: ApiKeyService {
    /// Fifo of the responses to `getConfig`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    /// Locked: refreshes call `getConfig` from tasks, concurrently with each other and with the test injecting.
    private var getConfigResponses = [Result<Com_Octopuscommunity_GetConfigResponse, RemoteClientError>]()
    private let lock = NSLock()
    /// The `bypassingCallsGate` value of each `getConfig` call, in order.
    private var _getConfigCalls = [Bool]()
    var getConfigCalls: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return _getConfigCalls
    }

    /// Number of times the config has been asked, read from the test while the refresh tasks call.
    var getConfigCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _getConfigCallCount
    }
    private var _getConfigCallCount = 0
    /// How long each `getConfig` takes to answer, once counted. Set before the calls under test.
    var getConfigDelay: TimeInterval = 0

    func getConfig(bypassingCallsGate: Bool) async throws(RemoteClientError) -> Com_Octopuscommunity_GetConfigResponse {
        guard let getConfigResponse = popNextGetConfigResponse(bypassingCallsGate: bypassingCallsGate) else {
            throw .unknown(MockError("Dev error, injectNextGetConfigResponse must be called before"))
        }
        if getConfigDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(getConfigDelay * 1_000_000_000))
        }
        return try getConfigResponse.get()
    }

    /// Counts the call and pops its response, under the lock: an `async` function cannot hold an `NSLock`.
    private func popNextGetConfigResponse(bypassingCallsGate: Bool)
    -> Result<Com_Octopuscommunity_GetConfigResponse, RemoteClientError>? {
        lock.lock()
        defer { lock.unlock() }
        _getConfigCallCount += 1
        _getConfigCalls.append(bypassingCallsGate)
        return getConfigResponses.popLast()
    }
}

extension MockApiKeyService {
    func injectNextGetConfigResponse(_ response: Com_Octopuscommunity_GetConfigResponse) {
        lock.lock()
        defer { lock.unlock() }
        getConfigResponses.insert(.success(response), at: 0)
    }

    func injectNextGetConfigError(_ error: RemoteClientError) {
        lock.lock()
        defer { lock.unlock() }
        getConfigResponses.insert(.failure(error), at: 0)
    }
}
