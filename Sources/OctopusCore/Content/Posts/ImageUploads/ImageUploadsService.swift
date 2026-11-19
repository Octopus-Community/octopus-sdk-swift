//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels
import OctopusDependencyInjection

extension Injected {
    static let imageUploadsService = Injector.InjectedIdentifier<ImageUploadsService>()
}

/// Uploads images to the storage through presigned URLs: asks the API for one URL per image (sending the byte size
/// of each, which the storage enforces), then PUTs each image's bytes to its URL.
final class ImageUploadsService: InjectableObject, @unchecked Sendable {
    // `@unchecked`: `OctopusRemoteClient` is not `Sendable`, and the service only holds immutable `let`s.
    static let injectedIdentifier = Injected.imageUploadsService

    /// Maximum number of PUTs in flight at the same time.
    static let maxConcurrentUploads = 3

    /// What a bridge post's images are uploaded for. Without it, the upload is a member upload.
    struct Bridge: Equatable, Sendable {
        /// The client object the post is created for. The images can only be used for that one.
        let clientObjectId: String
        /// The client token that signs the post, the same that is given when the post is created. `nil` or empty
        /// when the post is not signed.
        let clientToken: String?
    }

    enum Error: Swift.Error, Sendable {
        /// `CreateImageUploads` returned `fail`: the server's errors (at least one), each with its message, detail
        /// and optional 0-based image index.
        ///
        /// The index counts among the uploaded `images`, which for a bridge post are only its local images: it is not
        /// the position in the post's medias, where distant images sit too. Convert it before pointing at a media.
        case refused(Com_Octopuscommunity_CreateImageUploadsResponse.Fail)
        /// The API call failed (network, server).
        case serverCall(RemoteClientError)
        /// A PUT to the storage failed because the device has no usable connection: offline, connection lost or timed
        /// out, cellular data or roaming turned off, storage host unreachable (see `isNetworkLoss`).
        case noNetwork
        /// A PUT to the storage failed (status outside 200..<300 or transport error), or the response is malformed
        /// (missing result, uploads count different from images count, invalid URL).
        case uploadFailed
        /// The task that uploads was cancelled, which stops the call or the PUTs in flight. Told apart from a failure
        /// so that the caller who cancelled is not shown an error.
        case cancelled
    }

    private let remoteClient: OctopusRemoteClient
    private let httpClient: ImageUploadHTTPClient

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        httpClient = injector.getInjected(identifiedBy: Injected.imageUploadHTTPClient)
    }

    /// Uploads `images` (already compressed, in order) and returns their upload ids, in the same order.
    /// - Parameters:
    ///   - images: the bytes of each image, as they must be stored
    ///   - bridge: set when the images are for a bridge post, left `nil` for a member upload
    ///   - authenticationMethod: how to authenticate the call that asks for the upload URLs. The PUTs themselves are
    ///                           not authenticated.
    func upload(_ images: [Data], bridge: Bridge? = nil, authenticationMethod: AuthenticationMethod)
    async throws(Error) -> [String] {
        guard !images.isEmpty else { return [] }

        let response: Com_Octopuscommunity_CreateImageUploadsResponse
        do {
            response = try await remoteClient.octoService.createImageUploads(
                sizes: images.map { UInt64($0.count) }, bridge: bridge?.request, authenticationMethod: authenticationMethod)
        } catch {
            throw Task.isCancelled ? .cancelled : .serverCall(error)
        }

        let uploads: [Com_Octopuscommunity_CreateImageUploadsResponse.ImageUpload]
        switch response.result {
        case let .fail(fail):
            // A refusal without any error has no message to show: report it as a generic failure.
            guard !fail.errors.isEmpty else { throw .uploadFailed }
            throw .refused(fail)
        case let .success(success):
            uploads = success.uploads
        case nil:
            throw .uploadFailed
        }
        guard uploads.count == images.count else { throw .uploadFailed }
        // Parse every URL before the first PUT, so a malformed answer does not leave half of the images uploaded.
        var targets = [(id: String, url: URL)]()
        for upload in uploads {
            guard !upload.uploadID.isEmpty, let url = URL(string: upload.uploadURL) else { throw .uploadFailed }
            targets.append((id: upload.uploadID, url: url))
        }

        do {
            try await put(images, to: targets.map(\.url))
        } catch {
            if Self.isCancellation(error) { throw .cancelled }
            throw Self.isNetworkLoss(error) ? .noNetwork : .uploadFailed
        }
        return targets.map(\.id)
    }

    /// Whether the PUTs stopped because the task was cancelled: `URLSession` reports the tasks it cancels with
    /// `URLError.cancelled`, a cancelled wait throws `CancellationError`.
    private static func isCancellation(_ error: Swift.Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// Whether `error` is a transport error that means the device has no usable connection, as opposed to a storage
    /// that answered or refused.
    ///
    /// Beyond being offline, it counts cellular data turned off for the app (`dataNotAllowed`), roaming turned off
    /// (`internationalRoamingOff`) and a storage host that cannot be resolved or reached (`cannotFindHost`,
    /// `dnsLookupFailed`, `cannotConnectToHost`), which a captive Wi-Fi or a filtering network gives. All of them
    /// fail before the storage answers; `cannotConnectToHost` also covers a storage that is down, rare enough to be
    /// shown as a connection problem too.
    private static func isNetworkLoss(_ error: Swift.Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }

    /// PUTs `images[i]` to `urls[i]`, keeping at most `maxConcurrentUploads` PUTs in flight. The first failure
    /// cancels the PUTs still running and is thrown.
    private func put(_ images: [Data], to urls: [URL]) async throws {
        let httpClient = httpClient
        try await withThrowingTaskGroup(of: Void.self) { group in
            var nextIndex = 0
            func addNext() {
                let index = nextIndex
                nextIndex += 1
                group.addTask {
                    let status = try await httpClient.put(images[index], to: urls[index])
                    guard (200..<300).contains(status) else { throw Error.uploadFailed }
                }
            }
            for _ in 0..<min(Self.maxConcurrentUploads, images.count) { addNext() }
            while try await group.next() != nil {
                if nextIndex < images.count { addNext() }
            }
        }
    }
}

private extension ImageUploadsService.Bridge {
    var request: Com_Octopuscommunity_CreateImageUploadsRequest.BridgeUpload {
        .with {
            $0.clientObjectID = clientObjectId
            // An absent token is left out rather than sent empty: the backend tells "no token" from "a token".
            if let clientToken, !clientToken.isEmpty { $0.clientToken = clientToken }
        }
    }
}

extension ImageUploadsService.Error {
    /// The error to throw from an action that uploads images before calling the server.
    /// - Parameter validation: builds the action's validation error from the server's refusal.
    func asInputActionError<Validation: Sendable>(
        validation: (Com_Octopuscommunity_CreateImageUploadsResponse.Fail) -> Validation
    ) -> AuthenticatedInputActionError<Validation> {
        switch self {
        case let .refused(failure):
            .validation(validation(failure))
        case let .serverCall(remoteError):
            .serverCall(.serverError(ServerError(remoteClientError: remoteError)))
        case .noNetwork:
            .serverCall(.noNetwork)
        case .uploadFailed:
            .serverCall(.other(nil))
        case .cancelled:
            .serverCall(.other(CancellationError()))
        }
    }
}
