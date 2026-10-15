//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// One line of the sample's debug log, the iOS twin of the Android sample's `DebugEntry`.
struct DebugEntry: Identifiable, Equatable {
    /// What produced the line. Events and state changes come from the SDK; an API call is the host calling it.
    enum Category: String, CaseIterable, Identifiable {
        case event
        case state
        case apiCall

        var id: String { rawValue }

        var label: String {
            switch self {
            case .event: return "Event"
            case .state: return "State"
            case .apiCall: return "API Call"
            }
        }
    }

    let id: Int
    let timestamp: Date
    let category: Category
    let summary: String
    let details: String?
}

/// The log the Events log, the Debug console and Send feedback all read, as the Android sample's `DebugLog`:
/// every SDK event, the SDK's start and connection changes, and each feature toggle flip, capped at 200 lines.
/// Main thread only: every writer hops there first.
final class SampleDebugLog: ObservableObject {
    static let instance = SampleDebugLog()

    /// The Android cap: past it, the oldest lines go first.
    static let maxEntries = 200

    /// Oldest first, as they happened.
    @Published private(set) var entries: [DebugEntry] = []

    private var nextId = 0
    private var lastConnection: String?
    private let now: () -> Date
    private var sdkStorage = [AnyCancellable]()

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func add(_ category: DebugEntry.Category, _ summary: String, details: String? = nil) {
        entries.append(DebugEntry(id: nextId, timestamp: now(), category: category, summary: summary,
                                  details: details))
        nextId += 1
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }

    /// One typed SDK event, worded as Android prints it.
    func add(event: OctopusEvent) {
        let line = SampleEventFormat.line(for: event)
        add(.event, line.summary, details: line.details)
    }

    /// "SDK initialized" once the SDK is built, "SDK not initialized" when building it failed.
    func logInitialized(_ initialized: Bool) {
        add(.state, initialized ? "SDK initialized" : "SDK not initialized")
    }

    /// Logs the connection only when it changes, as Android does: a profile refresh is not a state change.
    func logConnection(_ connection: String) {
        guard connection != lastConnection else { return }
        lastConnection = connection
        add(.state, "Connection state changed", details: connection)
    }

    /// A feature toggle flip: the SDK config is rebuilt on it.
    func logToggle(_ toggle: FeatureToggle, enabled: Bool) {
        add(.state, "feature toggled → SDK config rebuilt",
            details: "\(toggle.label) -> \(enabled ? "on" : "off")\n\(toggle.effectLine(enabled: enabled))")
    }

    func clear() {
        entries = []
    }

    /// Follows a newly built SDK: logs its start, then every event it emits and every connection change. A
    /// community switch rebuilds the SDK and calls this again.
    func attach(octopus: OctopusSDK) {
        sdkStorage = []
        onMain { self.logInitialized(true) }
        octopus.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.add(event: $0) }
            .store(in: &sdkStorage)
        octopus.$profile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                let name = profile.flatMap { $0.isGuest ? nil : (AppUserManager.instance.appUser?.nickname
                    ?? $0.clientUserId) }
                self?.logConnection(Self.connectionLine(session: SampleSession(profile: profile), userName: name))
            }
            .store(in: &sdkStorage)
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    /// The connection line Android logs: "Connected (Guest)", "Connected (User: <name>)" or "Not Connected".
    static func connectionLine(session: SampleSession, userName: String?) -> String {
        guard session.hasProfile else { return "Not Connected" }
        if session.isGuest { return "Connected (Guest)" }
        return "Connected (User: \(userName ?? "member"))"
    }
}

/// Turns an `OctopusEvent` into the summary and details Android logs: the event's type name (the screen's, for a
/// screen display), then a Kotlin-like `Name(field=value, …)`.
enum SampleEventFormat {
    struct Line: Equatable {
        let summary: String
        let details: String
    }

    static func line(for event: OctopusEvent) -> Line {
        switch event {
        case let .screenDisplayed(context):
            return line(caseOf: context.screen)
        case let .contentDeleted(context):
            // Android emits one event per kind (PostDeleted, CommentDeleted, ReplyDeleted).
            let name = upperCamel(String(describing: context.kind)) + "Deleted"
            return Line(summary: name, details: render(name: name, payload: context))
        default:
            return line(caseOf: event)
        }
    }

    /// The case name in UpperCamel, and its associated value rendered field by field.
    private static func line(caseOf value: Any) -> Line {
        guard let child = Mirror(reflecting: value).children.first, let label = child.label else {
            let name = upperCamel(String(describing: value))
            return Line(summary: name, details: name)
        }
        let name = upperCamel(label)
        return Line(summary: name, details: render(name: name, payload: child.value))
    }

    /// `Name(a=1, b=x)`, or just `Name` when there is nothing to show, as a Kotlin data object prints.
    static func render(name: String, payload: Any) -> String {
        let fields = Mirror(reflecting: payload).children.compactMap { child -> String? in
            guard let label = child.label else { return nil }
            return "\(label)=\(describe(child.value))"
        }
        return fields.isEmpty ? name : "\(name)(\(fields.joined(separator: ", ")))"
    }

    static func describe(_ value: Any) -> String {
        if let text = value as? String { return text }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else { return "null" }
            return describe(wrapped)
        }
        if mirror.displayStyle == .set || mirror.displayStyle == .collection {
            let items = mirror.children.map { describe($0.value) }
            // A set has no order: sorting keeps the same set printing the same line.
            return "[" + (mirror.displayStyle == .set ? items.sorted() : items).joined(separator: ", ") + "]"
        }
        return stripModules(String(describing: value))
    }

    /// `Octopus.OctopusEvent.ReactionKind.heart` reads `heart`; nested type paths are noise in a log line.
    private static func stripModules(_ text: String) -> String {
        text.replacingOccurrences(of: #"\b(?:[A-Z][A-Za-z0-9]*\.)+"#, with: "", options: .regularExpression)
    }

    static func upperCamel(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
