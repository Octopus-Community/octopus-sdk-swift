//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// Why the directory could not be read, with the message shown to the developer.
enum FeatureEnvsError: Error {
    case notConfigured
    /// Told apart from `notConfigured` on purpose: "not configured" sends the developer looking for a
    /// missing secret when the value is in fact present and malformed.
    case invalidHost(String)
    case unauthorized
    case network(Error)
    case badResponse(Int)
    case tooLarge(Int)
    case undecodable(Error)

    var userMessage: String {
        switch self {
        case .notConfigured:
            return "Feature envs are not configured. Set OCTOPUS_FEATURE_ENVS_HOST and "
                 + "OCTOPUS_FEATURE_ENVS_TOKEN in secrets.xcconfig."
        case let .invalidHost(host):
            return "OCTOPUS_FEATURE_ENVS_HOST is not a usable host: '\(host)'. It must be a bare host, "
                 + "with no path and no query."
        case .unauthorized:
            return "The directory refused the token. Check OCTOPUS_FEATURE_ENVS_TOKEN in "
                 + "secrets.xcconfig — it may have been rotated."
        case let .network(error):
            // `localizedDescription`, never `\(error)`: interpolating a URLError prints its userInfo,
            // which carries the failing URL — and the token rides in that URL's query.
            return "Could not reach the directory: \(error.localizedDescription)"
        case let .badResponse(code):
            return "The directory answered HTTP \(code)."
        case let .tooLarge(bytes):
            return "The directory answered \(bytes) bytes, more than this Sample will read."
        case .undecodable:
            return "The directory answered something this Sample cannot read. It may have changed shape."
        }
    }
}

extension FeatureEnvsDirectory {

    /// How long to wait for the directory. `URLSession`'s 60 s default leaves "Loading…" on screen long
    /// enough that the developer assumes the screen is broken.
    private static let timeout: TimeInterval = 15

    /// Generous next to the few kB the directory sends, small enough to keep a surprise out of the decoder.
    private static let maxPayloadBytes = 512 * 1024

    /// Fetches and decodes the directory. Never logs the token.
    static func fetch() async throws(FeatureEnvsError) -> [FeatureEnv] {
        let url = try directoryUrl(host: DefaultValuesProvider.featureEnvsHost,
                                   token: DefaultValuesProvider.featureEnvsToken)

        print("Fetching feature envs from \(loggableUrl(url))")

        var request = URLRequest(url: url, timeoutInterval: timeout)
        // The answer is a live inventory: a cached copy would list envs that are already gone.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .network(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw http.statusCode == 401 || http.statusCode == 403 ? .unauthorized
                                                                   : .badResponse(http.statusCode)
        }

        guard data.count <= maxPayloadBytes else { throw .tooLarge(data.count) }

        do {
            return try decode(data)
        } catch {
            throw .undecodable(error)
        }
    }

    /// Builds the directory URL from a bare host and the token.
    ///
    /// The host is stored without a scheme (an xcconfig reads `//` as a comment), so `https://` is added
    /// here. A host pasted with its scheme is tolerated rather than producing `https://https://…`.
    static func directoryUrl(host: String, token: String) throws(FeatureEnvsError) -> URL {
        guard !host.isEmpty, !token.isEmpty else { throw .notConfigured }
        var components = URLComponents()
        components.scheme = "https"
        components.host = bareHost(from: host)
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else { throw .invalidHost(host) }
        return url
    }

    /// Session dedicated to the directory, for two reasons `URLSession.shared` cannot give:
    ///
    /// - **redirects are refused.** The token travels in the query string, so following a 302 would hand
    ///   it to whatever host the redirect names. The directory does not redirect; if it ever starts,
    ///   failing is the right outcome.
    /// - **ephemeral configuration**, so nothing about this request — including the URL carrying the
    ///   token — is written to an on-disk cache or cookie store.
    private static let session: URLSession = {
        URLSession(configuration: .ephemeral, delegate: RedirectRefusingDelegate.shared, delegateQueue: nil)
    }()

    private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate {
        static let shared = RedirectRefusingDelegate()

        func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    /// The URL without its query, so the token never reaches the console.
    static func loggableUrl(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        return components?.url?.absoluteString ?? url.host ?? "<url>"
    }
}
