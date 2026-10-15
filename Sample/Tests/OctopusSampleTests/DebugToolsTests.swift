//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusSample

/// Developer tools: the debug log behind the Events log and the Debug console, their formats, Send feedback's
/// issue URL, the Debug info lines and the network label.
@MainActor
final class DebugToolsTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func entry(_ id: Int, _ category: DebugEntry.Category, _ summary: String,
                       details: String? = nil) -> DebugEntry {
        DebugEntry(id: id, timestamp: start.addingTimeInterval(TimeInterval(id)), category: category,
                   summary: summary, details: details)
    }

    // MARK: - Debug log

    func testTheLogKeepsTheLast200LinesOldestFirst() {
        let log = SampleDebugLog(now: { self.start })
        (0..<205).forEach { log.add(.apiCall, "call \($0)") }
        XCTAssertEqual(log.entries.count, SampleDebugLog.maxEntries)
        XCTAssertEqual(log.entries.first?.summary, "call 5")
        XCTAssertEqual(log.entries.last?.summary, "call 204")
        log.clear()
        XCTAssertTrue(log.entries.isEmpty)
    }

    func testTheTrackingLogKeepsTheLast200EventsOldestFirst() {
        XCTAssertEqual(TrackingManager.maxEvents, SampleDebugLog.maxEntries)
        var log = [Int]()
        (0..<205).forEach { TrackingManager.append($0, to: &log, max: TrackingManager.maxEvents) }
        XCTAssertEqual(log.count, TrackingManager.maxEvents)
        XCTAssertEqual(log.first, 5)
        XCTAssertEqual(log.last, 204)
        var overfull = Array(0..<10)
        TrackingManager.append(10, to: &overfull, max: 3)
        XCTAssertEqual(overfull, [8, 9, 10])
    }

    func testTheConnectionIsLoggedOnlyWhenItChanges() {
        let log = SampleDebugLog(now: { self.start })
        log.logConnection("Connected (Guest)")
        log.logConnection("Connected (Guest)")
        log.logConnection("Not Connected")
        XCTAssertEqual(log.entries.map(\.details), ["Connected (Guest)", "Not Connected"])
        XCTAssertEqual(log.entries.first?.summary, "Connection state changed")
    }

    func testConnectionLineIsWordedAsAndroid() {
        XCTAssertEqual(SampleDebugLog.connectionLine(session: .none, userName: nil), "Not Connected")
        XCTAssertEqual(SampleDebugLog.connectionLine(
            session: SampleSession(hasProfile: true, isGuest: true, grantedEntitlements: []), userName: nil),
                       "Connected (Guest)")
        XCTAssertEqual(SampleDebugLog.connectionLine(
            session: SampleSession(hasProfile: true, isGuest: false, grantedEntitlements: []), userName: "Ada"),
                       "Connected (User: Ada)")
    }

    func testAToggleFlipSaysWhatItDid() {
        let log = SampleDebugLog(now: { self.start })
        log.logToggle(.forceLogin, enabled: true)
        XCTAssertEqual(log.entries.first?.summary, "feature toggled → SDK config rebuilt")
        XCTAssertEqual(log.entries.first?.details,
                       "Force login -> on\nVisitors must sign in before they can read or post.")
    }

    func testEventDetailsReadAsAKotlinDataClass() {
        struct Payload {
            let postId: String
            let text: String?
            let tags: Set<String>
        }
        XCTAssertEqual(SampleEventFormat.render(name: "PostCreated",
                                                payload: Payload(postId: "p1", text: nil, tags: ["b", "a"])),
                       "PostCreated(postId=p1, text=null, tags=[a, b])")
        XCTAssertEqual(SampleEventFormat.render(name: "SessionStopped", payload: ()), "SessionStopped")
        XCTAssertEqual(SampleEventFormat.upperCamel("postCreated"), "PostCreated")
    }

    // MARK: - Events log and Debug console

    func testEventsLogPlainTextNamesTheOriginAndIndentsTheDetails() {
        let text = EventsLogFormat.plainText([entry(0, .event, "PostCreated", details: "a\nb"),
                                              entry(1, .apiCall, "connectUser")])
        let lines = text.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].hasSuffix("  SDK   PostCreated"), lines[0])
        XCTAssertEqual(lines[1], "        a")
        XCTAssertEqual(lines[2], "        b")
        XCTAssertTrue(lines[3].hasSuffix("  HOST  connectUser"), lines[3])
    }

    func testDebugConsoleFiltersNewestFirstAndCopiesOldestFirst() {
        let entries = [entry(0, .event, "PostCreated", details: "postId=p1"),
                       entry(1, .state, "SDK initialized"),
                       entry(2, .apiCall, "connectUser")]
        let all = Set(DebugEntry.Category.allCases)
        XCTAssertEqual(DebugConsoleFormat.filter(entries, query: "", categories: all).map(\.id), [2, 1, 0])
        XCTAssertEqual(DebugConsoleFormat.filter(entries, query: " P1 ", categories: all).map(\.id), [0])
        XCTAssertEqual(DebugConsoleFormat.filter(entries, query: "", categories: [.state]).map(\.id), [1])

        let copied = DebugConsoleFormat.copyText(Array(entries.prefix(2))).split(separator: "\n").map(String.init)
        XCTAssertEqual(copied.count, 3)
        XCTAssertTrue(copied[0].hasSuffix("] [Event] PostCreated"), copied[0])
        XCTAssertEqual(copied[1], "  postId=p1")
        XCTAssertTrue(copied[2].hasSuffix("] [State] SDK initialized"), copied[2])
    }

    // MARK: - Send feedback

    private let context = SendFeedbackContext(platform: "iOS 26.0 · iPhone18,1", versions: "1.0 · sample 1 (1)",
                                              environment: "Demo", where: "Scenarios › Events",
                                              toggles: "Force login off · Push registration on")

    private func body(of url: String) -> String {
        let query = URLComponents(string: url)?.queryItems ?? []
        return query.first { $0.name == "body" }?.value ?? ""
    }

    func testTheIssueCarriesTheContextAndTheLast50LinesRedacted() {
        let log = (0..<60).map { entry($0, .event, "line \($0)") }
            + [entry(60, .apiCall, "token eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.abc")]
        let url = SendFeedbackURL.issueURL(repo: "owner/repo", context: context, comment: "", debugLog: log)
        XCTAssertTrue(url.hasPrefix("https://github.com/owner/repo/issues/new?labels=ios%2Cspotted&title="))
        let text = body(of: url)
        XCTAssertTrue(text.contains("_(no description)_"))
        XCTAssertTrue(text.contains("| Where | Scenarios › Events |"))
        XCTAssertTrue(text.contains("| Feature toggles | Force login off · Push registration on |"))
        XCTAssertFalse(text.contains("line 10\n"), "Only the last 50 lines ride along")
        XCTAssertTrue(text.contains("line 11\n"))
        XCTAssertTrue(text.contains("API Call  token ***"))
        XCTAssertFalse(text.contains("eyJhbGci"))
    }

    func testALongReportDropsOldLinesFirstThenCutsTheComment() {
        let log = (0..<50).map { entry($0, .event, String(repeating: "x", count: 20) + " \($0)") }
        let short = SendFeedbackURL.issueURL(repo: "owner/repo", context: context, comment: "ok", debugLog: log)
        XCTAssertLessThanOrEqual(short.count, SendFeedbackURL.maxURLLength)

        let comment = String(repeating: "word ", count: 3000)
        let long = SendFeedbackURL.issueURL(repo: "owner/repo", context: context, comment: comment, debugLog: log)
        XCTAssertLessThanOrEqual(long.count, SendFeedbackURL.maxURLLength)
        let text = body(of: long)
        XCTAssertTrue(text.contains("… 50 older lines dropped to fit the issue URL"))
        XCTAssertTrue(text.contains("_(comment truncated to fit the issue URL)_"))
    }

    func testRedactMasksKeyShapedTokensOnly() {
        XCTAssertEqual(SendFeedbackURL.redact("key test-pasted-key-0123456789 here"), "key *** here")
        XCTAssertEqual(SendFeedbackURL.redact("Scenarios › Events"), "Scenarios › Events")
    }

    func testFeatureTogglesSummaryLine() {
        XCTAssertEqual(FeatureToggles.summaryLine { $0 == .pushRegistration },
                       "Force login off · Push registration on")
    }

    // MARK: - Debug info

    func testAuthShortLabel() {
        XCTAssertEqual(DebugInfoSummary.authShortLabel(.sso(appManagedFields: [], forceLoginOnStrongActions: false)),
                       "SSO — no managed fields")
        XCTAssertEqual(DebugInfoSummary.authShortLabel(
            .sso(appManagedFields: [.nickname, .bio], forceLoginOnStrongActions: true)),
                       "SSO — force login, managed: nickname, bio")
        XCTAssertEqual(DebugInfoSummary.authShortLabel(
            .sso(appManagedFields: SDKConfig.ProfileField.allCases, forceLoginOnStrongActions: false)),
                       "SSO — all fields managed")
    }

    func testConnectionLine() {
        XCTAssertEqual(DebugInfoSummary.connection(profile: nil, nickname: "Ada"), "Not connected")
        XCTAssertEqual(DebugInfoSummary.connection(isGuest: true, userId: nil, nickname: nil), "Guest · read-only")
        XCTAssertEqual(DebugInfoSummary.connection(isGuest: false, userId: "u1", nickname: "Ada"),
                       "Connected · Ada · u1")
        XCTAssertEqual(DebugInfoSummary.connection(isGuest: false, userId: "u1", nickname: ""), "Connected · u1")
    }

    func testConfigurationLinesMaskTheKeyAndNameTheHost() {
        let demo = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: false))
        XCTAssertEqual(DebugInfoSummary.host(demo), "default (build)")
        let custom = SDKConfig(authKind: demo.authKind, customServer: .init(host: "api.custom.test", port: 443),
                               customApiKey: "test-pasted-key-0123456789")
        XCTAssertEqual(DebugInfoSummary.host(custom), "api.custom.test")

        let lines = DebugInfoSummary.configurationLines(config: custom, ssoUserId: nil, entitlementCount: 2,
                                                        theme: "Octopus · System", language: "English")
        XCTAssertEqual(lines.map(\.label), ["Server environment", "Host", "Community", "API key source", "SSO user",
                                            "Entitlements", "Theme", "Language", "API key"])
        XCTAssertEqual(lines[4].value, "Not signed in")
        XCTAssertEqual(lines[5].value, "2 entitlements")
        XCTAssertEqual(lines[8].value, "test…6789")
        XCTAssertFalse(lines.contains { $0.value.contains("pasted-key") }, "The key is never printed whole")

        XCTAssertEqual(DebugInfoSummary.configurationLines(config: nil, ssoUserId: "u1", entitlementCount: 0,
                                                           theme: "t", language: "l").map(\.value),
                       ["—", "—", "—", "—", "u1", "None", "t", "l", "—"])
    }

    func testWithoutASavedConfigurationTheBuiltInOneIsShownOutsideInternalMode() {
        XCTAssertNil(DebugInfoSummary.shownConfig(saved: nil, internalDemoMode: true))
        let shown = DebugInfoSummary.shownConfig(saved: nil, internalDemoMode: false)
        XCTAssertEqual(shown.map { DebugInfoSummary.authShortLabel($0.authKind) }, "SSO — no managed fields")
        let lines = DebugInfoSummary.configurationLines(config: shown, apiKey: "test-build-key-0123456789",
                                                        ssoUserId: nil, entitlementCount: 0, theme: "t",
                                                        language: "l")
        XCTAssertEqual(lines.first?.value, "Demo")
        XCTAssertEqual(lines[2].value, "Demo community")
        XCTAssertEqual(lines[3].value, "Demo preset · SSO · no managed fields · no forced login")
        XCTAssertEqual(lines[8].value, "test…6789")
    }

    func testTheConfigurationFooterPointsAtTheScreenOnlyWhenTheBuildHasOne() {
        XCTAssertEqual(DebugInfoSummary.configurationFooter(internalDemoMode: true), "Edit in Settings › Configuration")
        XCTAssertEqual(DebugInfoSummary.configurationFooter(internalDemoMode: false),
                       "Built into this build — it has no Configuration screen")
    }

    func testNetworkLabel() {
        XCTAssertEqual(SampleNetworkMonitor.label(isOnline: true, isForcedOffline: false), "Online")
        XCTAssertEqual(SampleNetworkMonitor.label(isOnline: false, isForcedOffline: false), "Offline")
        XCTAssertEqual(SampleNetworkMonitor.label(isOnline: true, isForcedOffline: true), "Offline · forced")
    }
}
