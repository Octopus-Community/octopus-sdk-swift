//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

// MARK: - Shared fakes for the tests that go through `ImageUploadsService`

extension Com_Octopuscommunity_CreateImageUploadsResponse {
    /// A success with `count` uploads, whose ids are `id<i>` and whose URLs are `FakeImageUploadHTTPClient.url(i)`.
    static func success(count: Int) -> Self {
        .with {
            $0.success = .with {
                $0.uploads = (0..<count).map { index in
                    .with {
                        $0.uploadID = "id\(index)"
                        $0.uploadURL = FakeImageUploadHTTPClient.url(index).absoluteString
                    }
                }
            }
        }
    }
}

/// A fake storage: records every PUT, can delay, answer another status or fail them per URL.
final class FakeImageUploadHTTPClient: ImageUploadHTTPClient, InjectableObject, Sendable {
    static let injectedIdentifier = Injected.imageUploadHTTPClient

    struct Put: Sendable {
        let body: Data
        let url: URL
    }

    /// What happened to a PUT, in the order it happened.
    enum Event: Equatable, Sendable {
        case started(URL)
        case finished(URL)
        /// The PUT was interrupted by the cancellation of the calling task.
        case cancelled(URL)
    }

    private struct TransportError: Swift.Error { }

    /// Bookkeeping, in an actor so that concurrent PUTs can record themselves safely.
    private actor Recorder {
        private(set) var puts = [Put]()
        private(set) var maxInFlight = 0
        private(set) var events = [Event]()
        private var inFlight = 0

        func begin(_ put: Put) {
            puts.append(put)
            events.append(.started(put.url))
            inFlight += 1
            maxInFlight = max(maxInFlight, inFlight)
        }

        func end(_ event: Event) {
            events.append(event)
            inFlight -= 1
        }
    }

    static func url(_ index: Int) -> URL { URL(string: "https://storage.example.com/upload/\(index)")! }

    private let recorder = Recorder()
    private let defaultDelay: TimeInterval
    private let delays: [URL: TimeInterval]
    private let statuses: [URL: Int]
    private let failingUrls: Set<URL>
    private let urlErrorCodes: [URL: URLError.Code]

    var puts: [Put] { get async { await recorder.puts } }
    var maxInFlight: Int { get async { await recorder.maxInFlight } }
    var events: [Event] { get async { await recorder.events } }

    /// - Parameters:
    ///   - failingUrls: the PUTs to these URLs fail with an opaque transport error
    ///   - urlErrorCodes: the PUTs to these URLs fail with a `URLError` of the given code
    init(defaultDelay: TimeInterval = 0, delays: [URL: TimeInterval] = [:], statuses: [URL: Int] = [:],
         failingUrls: Set<URL> = [], urlErrorCodes: [URL: URLError.Code] = [:]) {
        self.defaultDelay = defaultDelay
        self.delays = delays
        self.statuses = statuses
        self.failingUrls = failingUrls
        self.urlErrorCodes = urlErrorCodes
    }

    func put(_ body: Data, to url: URL) async throws -> Int {
        await recorder.begin(Put(body: body, url: url))
        do {
            let delay = delays[url] ?? defaultDelay
            if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        } catch {
            await recorder.end(.cancelled(url))
            throw error
        }
        await recorder.end(.finished(url))
        if let code = urlErrorCodes[url] { throw URLError(code) }
        if failingUrls.contains(url) { throw TransportError() }
        return statuses[url] ?? 200
    }
}
