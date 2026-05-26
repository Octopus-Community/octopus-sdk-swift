//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import Octopus

private typealias ValidationError = OctopusSDK.Configuration.ApiServer.ValidationError

@Suite("ApiServer validation")
struct ApiServerValidationTests {
    @Test func acceptsDnsHost() throws {
        let server = try OctopusSDK.Configuration.ApiServer(host: "api.example.com")
        #expect(server.host == "api.example.com")
        #expect(server.port == 443)
    }

    @Test func emptyHostThrows() {
        #expect(throws: ValidationError.emptyHost) {
            _ = try OctopusSDK.Configuration.ApiServer(host: "")
        }
    }

    @Test(arguments: [" api.example.com", "api.example.com ", "api .example.com", "\tapi.example.com"])
    func whitespaceHostThrows(host: String) {
        #expect(throws: ValidationError.hostContainsWhitespace) {
            _ = try OctopusSDK.Configuration.ApiServer(host: host)
        }
    }

    @Test(arguments: ["https://api.example.com", "grpc://api.example.com", "http://x"])
    func schemeHostThrows(host: String) {
        #expect(throws: ValidationError.hostContainsScheme) {
            _ = try OctopusSDK.Configuration.ApiServer(host: host)
        }
    }

    @Test(arguments: ["api.example.com/foo", "api.example.com?q=1", "api.example.com#frag", "user@api.example.com"])
    func pathOrAuthorityMetacharsThrow(host: String) {
        #expect(throws: ValidationError.hostContainsPortOrPath) {
            _ = try OctopusSDK.Configuration.ApiServer(host: host)
        }
    }

    // MARK: - Colon handling

    @Test func singleColonThrowsAsPortLeak() {
        #expect(throws: ValidationError.hostContainsPortOrPath) {
            _ = try OctopusSDK.Configuration.ApiServer(host: "api.example.com:443")
        }
    }

    @Test(arguments: ["::1", "2001:db8::1", "fe80::1"])
    func unbracketedIPv6Accepted(host: String) throws {
        let server = try OctopusSDK.Configuration.ApiServer(host: host)
        #expect(server.host == host)
    }

    @Test(arguments: ["[::1]", "[2001:db8::1]"])
    func bracketedIPv6Accepted(host: String) throws {
        let server = try OctopusSDK.Configuration.ApiServer(host: host)
        #expect(server.host == host)
    }

    @Test(arguments: ["[::1", "::1]", "[::1]x", "x[::1]", "[[::1]]", "[]"])
    func malformedBracketsThrow(host: String) {
        #expect(throws: ValidationError.invalidIPv6Bracketing) {
            _ = try OctopusSDK.Configuration.ApiServer(host: host)
        }
    }

    @Test func bracketedIPv6WithPortLeakThrows() {
        #expect(throws: ValidationError.invalidIPv6Bracketing) {
            _ = try OctopusSDK.Configuration.ApiServer(host: "[::1]:443")
        }
    }

    // MARK: - Happy paths

    @Test(arguments: ["api.example.com", "localhost", "xn--bcher-kva.example", "api.example.com.", "192.0.2.10"])
    func dnsAndIPv4Accepted(host: String) throws {
        let server = try OctopusSDK.Configuration.ApiServer(host: host)
        #expect(server.host == host)
        #expect(server.port == 443)
    }

    @Test func customPortStored() throws {
        let server = try OctopusSDK.Configuration.ApiServer(host: "api.example.com", port: 8443)
        #expect(server.port == 8443)
    }
}
