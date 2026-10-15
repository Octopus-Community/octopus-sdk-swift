//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Developer tools › Events log, the iOS twin of the Android `EventsScreen`: the sample's debug log, newest
/// first. Every row carries an origin pill, SDK for something the SDK emitted or decided, HOST for a call the
/// sample made into it, then the time and the raw detail in monospace.
struct EventsLogView: View {
    @ObservedObject private var log = SampleDebugLog.instance

    var body: some View {
        let rows = Array(log.entries.reversed())
        VStack(spacing: 0) {
            HStack(spacing: SampleTokens.Spacing.space2) {
                Text("\(rows.count) events")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityId("events-count")
                SecondaryPillButton(title: "Copy log", systemImage: "doc.on.doc", isEnabled: !rows.isEmpty,
                                    testId: "events-copy-log-button") {
                    UIPasteboard.general.string = EventsLogFormat.plainText(rows)
                }
                .fixedSize()
                SecondaryPillButton(title: "Clear", systemImage: "trash", isEnabled: !rows.isEmpty,
                                    testId: "events-clear-button") {
                    SampleDebugLog.instance.clear()
                    TrackingManager.instance.clear()
                }
                .fixedSize()
            }
            .padding(.horizontal, SampleTokens.Spacing.space4)
            .padding(.top, SampleTokens.Spacing.space3)

            if rows.isEmpty {
                SampleStateView(systemImage: "chart.line.uptrend.xyaxis", title: "No events yet",
                                message: "Events will appear here as you interact with the SDK")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: SampleTokens.Spacing.space2) {
                        ForEach(rows) { EventCard(entry: $0) }
                    }
                    .padding(SampleTokens.Spacing.space4)
                }
            }
        }
        .sampleScreenBackground()
        .navigationBarTitle("Events log", displayMode: .inline)
        .accessibilityId("events-screen")
        .hostAppFooter()
    }
}

private struct EventCard: View {
    let entry: DebugEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: SampleTokens.Spacing.space2) {
                OriginPill(origin: EventsLogFormat.Origin(entry.category))
                Text(entry.summary)
                    .font(SampleTokens.Typography.bodyStrong)
                    .foregroundColor(SampleTokens.Colors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(EventsLogFormat.time(entry.timestamp))
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
            }
            if let details = entry.details, !details.isEmpty {
                Text(details)
                    .font(SampleTokens.Typography.monoSmall)
                    .foregroundColor(SampleTokens.Colors.codeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SampleTokens.Spacing.space2)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.small)
                        .fill(SampleTokens.Colors.codeBackground))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SampleTokens.Spacing.space3)
        .sampleCardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityId("event-row")
    }
}

/// The DS LogRow tag: SDK is the info level, HOST the neutral tag. The word carries the meaning, not the hue.
private struct OriginPill: View {
    let origin: EventsLogFormat.Origin

    var body: some View {
        let sdk = origin == .sdk
        Text(origin.rawValue)
            .font(SampleTokens.Typography.monoSmall.weight(.semibold))
            .foregroundColor(sdk ? SampleTokens.Colors.accentText : SampleTokens.Colors.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(minHeight: 22)
            .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.small)
                .fill(sdk ? SampleTokens.Colors.accentTint : SampleTokens.Colors.surface3))
            .overlay(RoundedRectangle(cornerRadius: SampleTokens.Radius.small)
                .strokeBorder(sdk ? SampleTokens.Colors.accentText.opacity(0.35) : SampleTokens.Colors.outline,
                              lineWidth: 1))
    }
}

/// The DS state view: an icon disc, the fact, the way out.
struct SampleStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: SampleTokens.Spacing.space3) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(SampleTokens.Colors.accentText)
                .frame(width: SampleTokens.Size.stateDisc, height: SampleTokens.Size.stateDisc)
                .background(Circle().fill(SampleTokens.Colors.accentTint))
                .accessibilityHidden(true)
            Text(title)
                .font(SampleTokens.Typography.headline)
                .foregroundColor(SampleTokens.Colors.text)
            Text(message)
                .font(SampleTokens.Typography.callout)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(SampleTokens.Spacing.space6)
        .accessibilityElement(children: .combine)
    }
}

/// What the Events log prints and copies, kept pure for the tests.
enum EventsLogFormat {
    /// Which side of the SDK boundary produced the entry.
    enum Origin: String {
        case sdk = "SDK"
        case host = "HOST"

        /// A typed event or a state change is the SDK telling the host something; an API call is the host
        /// telling the SDK something.
        init(_ category: DebugEntry.Category) {
            switch category {
            case .event, .state: self = .sdk
            case .apiCall: self = .host
            }
        }
    }

    static func time(_ date: Date) -> String { formatter("HH:mm:ss").string(from: date) }

    /// One line per entry, `<ISO time>  <origin>  <summary>`, each detail line indented under it.
    static func plainText(_ entries: [DebugEntry]) -> String {
        let iso = formatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
        return entries.map { entry in
            var line = iso.string(from: entry.timestamp) + "  "
                + Origin(entry.category).rawValue.padding(toLength: 4, withPad: " ", startingAt: 0)
                + "  " + entry.summary
            if let details = entry.details, !details.isEmpty {
                line += details.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "\n        \($0)" }.joined()
            }
            return line
        }.joined(separator: "\n")
    }

    static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
