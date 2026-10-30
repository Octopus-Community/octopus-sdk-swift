//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

@Suite
struct GlassEffectTests {
    /// A value of `UIDesignRequiresCompatibility` as `Bundle.object(forInfoDictionaryKey:)` returns it.
    enum PlistValue: Sendable, CustomTestStringConvertible {
        case absent
        case bool(Bool)
        case number(Bool)
        case string(String)

        var value: Any? {
            switch self {
            case .absent: nil
            case let .bool(value): value
            case let .number(value): NSNumber(value: value)
            case let .string(value): value
            }
        }

        var testDescription: String {
            switch self {
            case .absent: "absent"
            case let .bool(value): "Bool \(value)"
            case let .number(value): "NSNumber \(value)"
            case let .string(value): "String \"\(value)\""
            }
        }
    }

    struct Case: Sendable, CustomTestStringConvertible {
        let osSupportsGlass: Bool
        let osHonorsCompatibilityKey: Bool
        let key: PlistValue
        let expected: Bool

        var testDescription: String {
            "OS glass: \(osSupportsGlass), key honored: \(osHonorsCompatibilityKey), key: \(key.testDescription)"
        }
    }

    @Test(arguments: [
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .absent, expected: true),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .bool(false), expected: true),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .bool(true), expected: false),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .number(true), expected: false),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .number(false), expected: true),
        // iOS only honors a boolean: a string, even "YES", leaves the glass effect on.
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .string("YES"), expected: true),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: true, key: .string("NO"), expected: true),
        // An app linked against the iOS 27 SDK, running on iOS 27, gets the glass effect whatever the key says.
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: false, key: .bool(true), expected: true),
        Case(osSupportsGlass: true, osHonorsCompatibilityKey: false, key: .absent, expected: true),
        Case(osSupportsGlass: false, osHonorsCompatibilityKey: true, key: .absent, expected: false),
        Case(osSupportsGlass: false, osHonorsCompatibilityKey: true, key: .bool(false), expected: false),
        Case(osSupportsGlass: false, osHonorsCompatibilityKey: true, key: .bool(true), expected: false),
    ])
    func isAvailable(_ testCase: Case) {
        #expect(GlassEffect.isAvailable(
            osSupportsGlass: testCase.osSupportsGlass,
            osHonorsCompatibilityKey: testCase.osHonorsCompatibilityKey,
            designRequiresCompatibility: testCase.key.value) == testCase.expected)
    }
}
