//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing

/// The texts that address the member come in pairs in the string catalog: `<key>.Formal…` and `<key>.Informal…`,
/// the tone suffix sitting before the arguments. The code picks one of the two at runtime, so a pair missing a half,
/// a language or an argument shows a raw key or a wrong value to part of the members.
struct TonedStringCatalogTests {
    private static let formalSuffix = ".Formal"
    private static let informalSuffix = ".Informal"

    private let strings: [String: [String: Any]]
    private let sources: URL

    init() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        sources = root.appendingPathComponent("Sources/OctopusUI")
        let catalog = sources.appendingPathComponent("Resources/Localizable.xcstrings")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any]
        strings = try #require(json?["strings"] as? [String: [String: Any]])
    }

    @Test func everyFormalTextHasAnInformalOne() {
        let formalKeys = strings.keys.filter { $0.contains(Self.formalSuffix) }
        #expect(!formalKeys.isEmpty)
        for formalKey in formalKeys {
            let informalKey = formalKey.replacingOccurrences(of: Self.formalSuffix, with: Self.informalSuffix)
            #expect(strings[informalKey] != nil, "\(formalKey) has no \(informalKey)")
        }
        for informalKey in strings.keys where informalKey.contains(Self.informalSuffix) {
            let formalKey = informalKey.replacingOccurrences(of: Self.informalSuffix, with: Self.formalSuffix)
            #expect(strings[formalKey] != nil, "\(informalKey) has no \(formalKey)")
        }
    }

    @Test func bothVersionsHaveTheSameLanguagesAndArguments() throws {
        for formalKey in strings.keys where formalKey.contains(Self.formalSuffix) {
            let informalKey = formalKey.replacingOccurrences(of: Self.formalSuffix, with: Self.informalSuffix)
            let formal = try #require(localizedValues(of: formalKey))
            let informal = try #require(localizedValues(of: informalKey))

            #expect(Set(formal.keys) == Set(informal.keys), "\(formalKey): not the same languages")
            for (language, formalValue) in formal {
                let informalValue = informal[language] ?? ""
                #expect(!informalValue.isEmpty, "\(informalKey) is empty in \(language)")
                #expect(arguments(of: formalValue) == arguments(of: informalValue),
                        "\(formalKey): not the same arguments in \(language)")
            }
        }
    }

    /// The suffix goes before the arguments, so that the code can write both keys as literals around the same
    /// interpolations.
    @Test func theToneSuffixComesBeforeTheArguments() {
        for key in strings.keys where key.contains(Self.formalSuffix) || key.contains(Self.informalSuffix) {
            let suffix = key.contains(Self.formalSuffix) ? Self.formalSuffix : Self.informalSuffix
            let afterSuffix = key.components(separatedBy: suffix).dropFirst().joined(separator: suffix)
            #expect(afterSuffix.isEmpty || afterSuffix.hasPrefix("_"), "\(key): the tone is not the last word")
        }
    }

    /// The code writes both keys as literals: a typo in one of them shows the raw key to the members of that tone.
    @Test func everyTonedKeyOfTheCodeIsInTheCatalog() throws {
        let catalogKeys = Set(strings.keys.map(Self.withoutArguments))
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\\n]|\\\([^)]*\))*\.(?:Formal|Informal)(?:[^"\\\n]|\\\([^)]*\))*)""#)
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        var keyCount = 0
        for file in files {
            let code = try String(contentsOf: file, encoding: .utf8)
            for match in literal.matches(in: code, range: NSRange(code.startIndex..., in: code)) {
                guard let range = Range(match.range(at: 1), in: code) else { continue }
                let key = String(code[range])
                keyCount += 1
                #expect(catalogKeys.contains(Self.withoutArguments(key)),
                        "\(file.lastPathComponent): \(key) is not in the catalog")
            }
        }
        #expect(keyCount > 100)
    }

    /// A key with its arguments blanked out, so that `TooLong.Formal_currentLength:\(count)` in the code and
    /// `TooLong.Formal_currentLength:%lld` in the catalog compare equal.
    private static func withoutArguments(_ key: String) -> String {
        key.replacingOccurrences(of: #"\\\([^)]*\)|%(?:\d+\$)?(?:lld|ld|d|@)"#, with: "%", options: .regularExpression)
    }

    private func localizedValues(of key: String) -> [String: String]? {
        guard let localizations = strings[key]?["localizations"] as? [String: [String: Any]] else { return nil }
        return localizations.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
    }

    /// The format specifiers of a value, sorted: `%1$@`, `%2$lld`… A value may write them in another order than
    /// another language does, never another set.
    private func arguments(of value: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:lld|ld|d|@)")
        let range = NSRange(value.startIndex..., in: value)
        return (regex?.matches(in: value, range: range) ?? [])
            .compactMap { Range($0.range, in: value).map { String(value[$0]) } }
            .sorted()
    }
}
