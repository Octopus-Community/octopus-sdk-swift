//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

public extension OctopusSDK.Configuration {
    /// Server endpoint the SDK targets.
    struct ApiServer {
        /// Host. Accepts:
        ///   - A DNS name (e.g. `"api.example.com"`).
        ///   - An IPv4 literal (e.g. `"192.0.2.10"`).
        ///   - An IPv6 literal, either bracketed (`"[::1]"`) or unbracketed
        ///     (`"::1"`).
        /// Must not contain a scheme (`https://`), an embedded port (`:443`),
        /// a path, or whitespace.
        public let host: String
        /// Port. Defaults to 443.
        public let port: Int

        /// Constructs a custom server endpoint. The host is validated at
        /// construction time and the initializer throws on invalid input.
        ///
        /// - Throws: ``ValidationError`` on invalid input.
        public init(host: String, port: Int = 443) throws(ValidationError) {
            try Self.validate(host: host)
            self.host = host
            self.port = port
        }

        private static func validate(host: String) throws(ValidationError) {
            guard !host.isEmpty else { throw .emptyHost }
            if host.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                throw .hostContainsWhitespace
            }
            if host.contains("://") {
                throw .hostContainsScheme
            }
            let forbidden: Set<Character> = ["/", "?", "#", "@"]
            if host.contains(where: { forbidden.contains($0) }) {
                throw .hostContainsPortOrPath
            }

            // Bracket / IPv6 handling.
            if host.first == "[" {
                guard host.last == "]", host.count >= 3 else {
                    throw .invalidIPv6Bracketing
                }
                let inner = host.dropFirst().dropLast()
                if inner.contains("[") || inner.contains("]") {
                    throw .invalidIPv6Bracketing
                }
                // `:` is allowed inside brackets (IPv6 separator). No further checks here —
                // grpc-swift / NIO will surface a connection error if the literal is invalid.
                return
            }
            // Stray brackets without leading `[` are malformed.
            if host.contains("[") || host.contains("]") {
                throw .invalidIPv6Bracketing
            }

            // Colon rule: exactly one `:` = looks like host:port, reject. Two or more
            // = unbracketed IPv6 literal, accept.
            let colonCount = host.filter { $0 == ":" }.count
            if colonCount == 1 {
                throw .hostContainsPortOrPath
            }
        }
    }
}

public extension OctopusSDK.Configuration.ApiServer {
    /// Errors thrown by ``OctopusSDK/Configuration/ApiServer/init(host:port:)``.
    enum ValidationError: Error, Sendable, CustomDebugStringConvertible {
        /// The host string is empty.
        case emptyHost
        /// The host string contains a scheme (e.g. `"https://"`).
        case hostContainsScheme
        /// The host string contains a path or URL-authority metacharacter
        /// (`/`, `?`, `#`, `@`), or a single `:` that looks like a port
        /// separator (use the `port` parameter instead).
        case hostContainsPortOrPath
        /// The host string contains whitespace.
        case hostContainsWhitespace
        /// The host string is malformed as an IPv6 bracketed literal (e.g.
        /// opening `[` without closing `]`, characters before/after the
        /// brackets, or nested brackets).
        case invalidIPv6Bracketing

        public var debugDescription: String {
            switch self {
            case .emptyHost:
                return "ApiServer host is empty."
            case .hostContainsScheme:
                return "ApiServer host must not contain a scheme (e.g. 'https://')."
            case .hostContainsPortOrPath:
                return """
                    ApiServer host must not contain a path, a port, or URL-authority metacharacters \
                    ('/', '?', '#', '@', ':'). Use the port parameter instead.
                    """
            case .hostContainsWhitespace:
                return "ApiServer host must not contain whitespace."
            case .invalidIPv6Bracketing:
                return "ApiServer host is a malformed IPv6 bracketed literal."
            }
        }
    }
}
