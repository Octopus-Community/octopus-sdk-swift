//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The Debug console, the iOS twin of the Android sample's bottom sheet: the sample's debug log, newest first,
/// searchable and filtered by category, with Copy All, Clear Log and Close in its header. Opened from the bug
/// button of every host page and from Developer tools › Debug console.
struct DebugConsoleSheet: View {
    /// The presenter's own flag: Close clears it rather than asking the environment to dismiss, which a page
    /// holding two sheet presenters (Developer tools has its own plus the bug button's) did not always honour.
    @Binding var isPresented: Bool
    @ObservedObject private var log = SampleDebugLog.instance
    @State private var searchQuery = ""
    @State private var activeFilters = Set(DebugEntry.Category.allCases)

    var body: some View {
        let entries = log.entries
        let filtered = DebugConsoleFormat.filter(entries, query: searchQuery, categories: activeFilters)
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space2) {
            header(entries)
            TextField("Search logs...", text: $searchQuery)
                .font(SampleTokens.Typography.callout)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, SampleTokens.Spacing.space3)
                .frame(minHeight: SampleTokens.Size.touchMin)
                .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                    .fill(SampleTokens.Colors.surface))
                .overlay(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
                    .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
                .accessibilityId("debug-search-field")
            ChipFlow(spacing: SampleTokens.Spacing.space2) {
                ForEach(DebugEntry.Category.allCases) { category in
                    SampleChip(title: "\(category.label) (\(entries.filter { $0.category == category }.count))",
                               isSelected: activeFilters.contains(category)) {
                        if activeFilters.contains(category) {
                            activeFilters.remove(category)
                        } else {
                            activeFilters.insert(category)
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityId("debug-filter-select")
            Text("\(filtered.count) of \(entries.count) entries")
                .font(SampleTokens.Typography.caption)
                .foregroundColor(SampleTokens.Colors.textSecondary)
                .accessibilityId("debug-entry-count")
            if filtered.isEmpty {
                SampleStateView(
                    systemImage: "terminal",
                    title: entries.isEmpty ? "No entries yet" : "No matching entries",
                    message: entries.isEmpty ? "SDK events, state changes and API calls land here as they happen."
                        : "Nothing matches the current filters.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: SampleTokens.Spacing.space1) {
                        ForEach(filtered) { DebugEntryRow(entry: $0) }
                    }
                }
                .accessibilityId("debug-log-list")
            }
        }
        .padding(.horizontal, SampleTokens.Spacing.space4)
        .padding(.top, SampleTokens.Spacing.space4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sampleScreenBackground()
        .accessibilityId("debug-console-sheet")
        .modify {
            if #available(iOS 16.0, *) {
                $0.presentationDetents([.medium, .large])
            } else {
                $0
            }
        }
    }

    private func header(_ entries: [DebugEntry]) -> some View {
        HStack(spacing: 0) {
            Text("Debug Console")
                .font(SampleTokens.Typography.headline)
                .foregroundColor(SampleTokens.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            iconButton("doc.on.doc", label: "Copy All", id: "debug-copy-button") {
                UIPasteboard.general.string = DebugConsoleFormat.copyText(entries)
            }
            iconButton("trash", label: "Clear Log", id: "debug-clear-button") {
                SampleDebugLog.instance.clear()
            }
            iconButton("xmark", label: "Close", id: "debug-close-button") {
                isPresented = false
            }
        }
    }

    private func iconButton(_ systemImage: String, label: String, id: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundColor(SampleTokens.Colors.text)
                .frame(width: SampleTokens.Size.touchMin, height: SampleTokens.Size.touchMin)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabelCompat(label)
        .accessibilityId(id)
    }
}

private struct DebugEntryRow: View {
    let entry: DebugEntry
    @State private var expanded = false

    var body: some View {
        let hasDetails = entry.details != nil
        VStack(alignment: .leading, spacing: SampleTokens.Spacing.space1) {
            HStack(spacing: 6) {
                Text(DebugConsoleFormat.time(entry.timestamp))
                    .font(SampleTokens.Typography.monoSmall)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                CategoryTag(category: entry.category)
                Text(entry.summary)
                    .font(SampleTokens.Typography.caption.weight(.medium))
                    .foregroundColor(SampleTokens.Colors.text)
                    .lineLimit(expanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hasDetails {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(SampleTokens.Colors.text.opacity(0.3))
                        .accessibilityHidden(true)
                }
            }
            if expanded, let details = entry.details {
                Text(details)
                    .font(SampleTokens.Typography.monoSmall)
                    .foregroundColor(SampleTokens.Colors.codeText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(SampleTokens.Colors.codeBackground))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SampleTokens.Spacing.space2)
        .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium).fill(SampleTokens.Colors.surface2))
        .contentShape(Rectangle())
        .onTapGesture { if hasDetails { expanded.toggle() } }
        .accessibilityElement(children: .combine)
        .accessibilityId("debug-entry-row")
    }
}

/// Event in the accent, State in success, API Call in warning: the Android tag colours.
private struct CategoryTag: View {
    let category: DebugEntry.Category

    var body: some View {
        let (fill, ink): (Color, Color) = {
            switch category {
            case .event: return (SampleTokens.Colors.accentTint, SampleTokens.Colors.accentText)
            case .state: return (SampleTokens.Colors.successTint, SampleTokens.Colors.successText)
            case .apiCall: return (SampleTokens.Colors.warningTint, SampleTokens.Colors.warningText)
            }
        }()
        Text(category.label)
            .font(SampleTokens.Typography.badgeLabel)
            .foregroundColor(ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.small).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: SampleTokens.Radius.small)
                .strokeBorder(ink.opacity(0.45), lineWidth: 1))
    }
}

/// What the Debug console filters and copies, kept pure for the tests.
enum DebugConsoleFormat {
    /// Newest first, as Android lists them; the search matches the summary or the details, case-insensitively.
    static func filter(_ entries: [DebugEntry], query: String,
                       categories: Set<DebugEntry.Category>) -> [DebugEntry] {
        let query = query.trimmingCharacters(in: .whitespaces)
        return entries.filter { entry in
            categories.contains(entry.category) && (query.isEmpty
                || entry.summary.range(of: query, options: .caseInsensitive) != nil
                || entry.details?.range(of: query, options: .caseInsensitive) != nil)
        }.reversed()
    }

    static func time(_ date: Date) -> String { EventsLogFormat.formatter("HH:mm:ss.SSS").string(from: date) }

    /// Copy All: every entry, oldest first, `[time] [Category] summary` and its details indented below.
    static func copyText(_ entries: [DebugEntry]) -> String {
        entries.map { entry in
            "[\(time(entry.timestamp))] [\(entry.category.label)] \(entry.summary)"
                + (entry.details.map { "\n  \($0)" } ?? "")
        }.joined(separator: "\n")
    }
}
