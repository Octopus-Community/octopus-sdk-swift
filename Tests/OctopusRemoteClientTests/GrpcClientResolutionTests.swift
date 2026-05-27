//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusRemoteClient

@Suite("GrpcClient.resolveBaseURL")
struct GrpcClientResolutionTests {
    @Test func overridePresentReturnedAsIs() {
        let result = GrpcClient.resolveBaseURL(
            override: (host: "octopus-waf.example.com", port: 8443),
            infoDictionary: nil
        )
        #expect(result.host == "octopus-waf.example.com")
        #expect(result.port == 8443)
    }

    @Test func overrideAbsentUsesInfoPlistKey() {
        let result = GrpcClient.resolveBaseURL(
            override: nil,
            infoDictionary: ["OCTOPUS_REMOTE_BASE_URL": "api-demo2.8pus.io"]
        )
        #expect(result.host == "api-demo2.8pus.io")
        #expect(result.port == 443)
    }

    @Test func overrideAbsentInfoPlistEmptyFallsBackToDefault() {
        let result = GrpcClient.resolveBaseURL(
            override: nil,
            infoDictionary: ["OCTOPUS_REMOTE_BASE_URL": ""]
        )
        #expect(result.host == "api.8pus.io")
        #expect(result.port == 443)
    }

    @Test func overrideAbsentInfoPlistAbsentUsesDefault() {
        let result = GrpcClient.resolveBaseURL(
            override: nil,
            infoDictionary: nil
        )
        #expect(result.host == "api.8pus.io")
        #expect(result.port == 443)
    }

    @Test func bracketedIPv6OverrideKeptForResolver() {
        let result = GrpcClient.resolveBaseURL(
            override: (host: "[::1]", port: 443),
            infoDictionary: nil
        )
        // Resolver returns the host as the public layer stored it.
        // Brackets are stripped by stripIPv6Brackets at the GrpcClient handoff,
        // not here.
        #expect(result.host == "[::1]")
    }
}

@Suite("GrpcClient.stripIPv6Brackets")
struct GrpcClientStripIPv6BracketsTests {
    @Test func bracketedIPv6IsStripped() {
        #expect(GrpcClient.stripIPv6Brackets("[::1]") == "::1")
        #expect(GrpcClient.stripIPv6Brackets("[2001:db8::1]") == "2001:db8::1")
    }

    @Test func nonBracketedHostIsPassthrough() {
        #expect(GrpcClient.stripIPv6Brackets("api.example.com") == "api.example.com")
        #expect(GrpcClient.stripIPv6Brackets("192.0.2.10") == "192.0.2.10")
        #expect(GrpcClient.stripIPv6Brackets("::1") == "::1")
    }

    @Test func unbalancedBracketsArePassedThrough() {
        #expect(GrpcClient.stripIPv6Brackets("[::1") == "[::1")
        #expect(GrpcClient.stripIPv6Brackets("::1]") == "::1]")
    }

    @Test func shortStringsArePassedThrough() {
        #expect(GrpcClient.stripIPv6Brackets("") == "")
        #expect(GrpcClient.stripIPv6Brackets("[") == "[")
    }
}
