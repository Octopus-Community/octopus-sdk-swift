//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

@Suite(.serialized)
struct URLSessionImageUploadHTTPClientTests {
    @Test func putSendsTheSniffedContentTypeAndNoCredentials() async throws {
        StubURLProtocol.reset(status: 204)
        let sut = URLSessionImageUploadHTTPClient(session: StubURLProtocol.makeSession())
        let url = URL(string: "https://storage.example.com/upload/1?signature=abc")!

        let status = try await sut.put(Data([0xFF, 0xD8, 0xFF, 0xE0, 1, 2]), to: url)

        #expect(status == 204)
        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.httpMethod == "PUT")
        #expect(request.url == url)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func defaultSessionSharesNothingWithTheHostApp() {
        let session = URLSessionImageUploadHTTPClient.defaultSession
        #expect(session !== URLSession.shared)
        let configuration = session.configuration
        #expect(configuration.httpCookieStorage == nil)
        #expect(configuration.httpShouldSetCookies == false)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.urlCache == nil)
    }

    @Test func putFallsBackToOctetStreamForUnknownBytes() async throws {
        StubURLProtocol.reset(status: 200)
        let sut = URLSessionImageUploadHTTPClient(session: StubURLProtocol.makeSession())

        _ = try await sut.put(Data([1, 2, 3]), to: URL(string: "https://storage.example.com/upload/2")!)

        let request = try #require(StubURLProtocol.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
    }

    @Test func aPutWhoseTaskIsCancelledBeforeItStartsThrowsAndSendsNothing() async throws {
        // The stub would answer 200: only the cancellation can make the call throw.
        StubURLProtocol.reset(status: 200)
        let sut = URLSessionImageUploadHTTPClient(session: StubURLProtocol.makeSession())
        let url = URL(string: "https://storage.example.com/upload/3")!

        let task = Task {
            // Cancel the task from inside, so that it is cancelled before `put` begins.
            withUnsafeCurrentTask { $0?.cancel() }
            return try await sut.put(Data([1, 2, 3]), to: url)
        }

        await #expect(throws: (any Error).self) { try await task.value }
        #expect(StubURLProtocol.lastRequest == nil)
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _lastRequest: URLRequest?
    nonisolated(unsafe) private static var status = 200

    static var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _lastRequest
    }

    static func reset(status: Int) {
        lock.lock()
        defer { lock.unlock() }
        _lastRequest = nil
        self.status = status
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    // `URLProtocol` declares these as class methods: the overrides have to stay `class`.
    // swiftlint:disable static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    // swiftlint:enable static_over_final_class

    override func startLoading() {
        Self.lock.lock()
        Self._lastRequest = request
        let status = Self.status
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
