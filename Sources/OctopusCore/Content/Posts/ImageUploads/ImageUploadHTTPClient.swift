//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

extension Injected {
    static let imageUploadHTTPClient = Injector.InjectedIdentifier<ImageUploadHTTPClient>()
}

/// PUTs bytes to a presigned URL. A protocol so tests can fake the storage the URLs point to.
protocol ImageUploadHTTPClient: Sendable {
    /// Sends `body` to `url` with an HTTP PUT.
    /// - Returns: the HTTP status code of the response.
    func put(_ body: Data, to url: URL) async throws -> Int
}

/// `ImageUploadHTTPClient` backed by a `URLSession` of its own.
///
/// The request carries no authentication header: the signature that authorizes the upload is part of the URL, and
/// the storage rejects a request that adds credentials of its own. Its only header is the `Content-Type` of the image,
/// sniffed from the bytes.
final class URLSessionImageUploadHTTPClient: ImageUploadHTTPClient, InjectableObject, Sendable {
    static let injectedIdentifier = Injected.imageUploadHTTPClient

    /// Dedicated to the uploads, so that they share nothing with the host app: `URLSession.shared` also runs the URL
    /// protocols an app registers globally (network inspectors would then see the presigned URLs), and keeps cookies,
    /// credentials and a cache the uploads have no use for.
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private let session: URLSession

    init(session: URLSession = URLSessionImageUploadHTTPClient.defaultSession) {
        self.session = session
    }

    func put(_ body: Data, to url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(ImageUploadContentType.detect(from: body), forHTTPHeaderField: "Content-Type")

        // `URLSession`'s async upload API needs iOS 15: bridge the completion-handler one, and cancel the task
        // when the calling task is cancelled.
        let taskHolder = UploadTaskHolder()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let task = session.uploadTask(with: request, from: body) { _, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let httpResponse = response as? HTTPURLResponse {
                        continuation.resume(returning: httpResponse.statusCode)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                guard taskHolder.set(task) else {
                    task.cancel()
                    return
                }
                task.resume()
            }
        } onCancel: {
            taskHolder.cancel()
        }
    }
}

/// Holds the running upload task so that a cancellation that arrives from another thread can reach it.
private final class UploadTaskHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var isCancelled = false

    /// Stores the task. Returns `false` when the holder was already cancelled, in which case the caller must
    /// cancel the task instead of starting it.
    func set(_ task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled else { return false }
        self.task = task
        return true
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }
}

/// The `Content-Type` to send with an uploaded image, deduced from its first bytes.
enum ImageUploadContentType {
    static let fallback = "application/octet-stream"

    private static let heicBrands: Set<String> = [
        "heic", "heix", "hevc", "heim", "heis", "hevm", "hevs", "mif1", "msf1"
    ]

    static func detect(from data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        func starts(with prefix: [UInt8], at offset: Int = 0) -> Bool {
            bytes.count >= offset + prefix.count && Array(bytes[offset..<(offset + prefix.count)]) == prefix
        }
        func ascii(_ string: String) -> [UInt8] { Array(string.utf8) }

        if starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        if starts(with: ascii("RIFF")), starts(with: ascii("WEBP"), at: 8) { return "image/webp" }
        if starts(with: ascii("ftyp"), at: 4), bytes.count >= 12,
           let brand = String(bytes: bytes[8..<12], encoding: .ascii), heicBrands.contains(brand) {
            return "image/heic"
        }
        return fallback
    }
}
