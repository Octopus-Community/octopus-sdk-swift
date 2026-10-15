//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Settings › Send feedback, internal builds only, the iOS twin of the Android sheet: it lists everything that
/// will leave the device before anything does, then opens a pre-filled GitHub issue in the browser.
///
/// - Never a key: the environment is a label, and the comment and log lines are redacted on the way out.
/// - Never a community name: only the environment label ships.
/// - No token: the app builds an `issues/new` URL and hands it to the browser, where the reporter is signed in.
///
/// The row that opens it needs internal demo mode and a non-empty `OCTOPUS_FEEDBACK_REPO`, which has no default.
struct SendFeedbackSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var comment = ""

    private let context = SendFeedbackContext.current()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Send feedback")
                    .font(SampleTokens.Typography.headline)
                    .foregroundColor(SampleTokens.Colors.text)
                Text("A GitHub issue will be opened in the sample's repository, pre-filled with:")
                    .font(SampleTokens.Typography.caption)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                SettingsInfoRow(label: "Platform", value: context.platform)
                SettingsInfoRow(label: "SDK", value: context.versions)
                SettingsInfoRow(label: "Environment", value: "\(context.environment) — name only, never the key")
                SettingsInfoRow(label: "Where", value: context.where)
                SettingsInfoRow(label: "Feature toggles", value: context.toggles)
                SettingsInfoRow(label: "Debug console", value: "last \(SendFeedbackURL.logLines) lines, redacted")
                commentField
                HStack(spacing: SampleTokens.Spacing.space2) {
                    SecondaryPillButton(title: "Cancel", testId: "send-feedback-cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    PrimaryPillButton(title: "Open GitHub issue", testId: "send-feedback-submit") {
                        open(SendFeedbackURL.issueURL(repo: DefaultValuesProvider.feedbackRepo, context: context,
                                                      comment: comment, debugLog: SampleDebugLog.instance.entries))
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, SampleTokens.Spacing.space5)
        }
        .sampleScreenBackground()
        .accessibilityId("send-feedback-sheet")
    }

    private var commentField: some View {
        ZStack(alignment: .topLeading) {
            if comment.isEmpty {
                Text("What went wrong, or what you expected?")
                    .font(SampleTokens.Typography.body)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .padding(.horizontal, SampleTokens.Spacing.space3)
                    .padding(.vertical, SampleTokens.Spacing.space3)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $comment)
                .font(SampleTokens.Typography.body)
                .padding(.horizontal, SampleTokens.Spacing.space2)
                .padding(.vertical, SampleTokens.Spacing.space1)
                .frame(minHeight: 96)
                .modify {
                    if #available(iOS 16.0, *) { $0.scrollContentBackground(.hidden) } else { $0 }
                }
                .accessibilityLabelCompat("What went wrong, or what you expected?")
                .accessibilityId("send-feedback-comment")
        }
        .background(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
            .fill(SampleTokens.Colors.surface))
        .overlay(RoundedRectangle(cornerRadius: SampleTokens.Radius.medium, style: .continuous)
            .strokeBorder(SampleTokens.Colors.outline, lineWidth: 1))
    }

    /// Opens the browser, or copies the link when nothing can open it, as Android's `openUrlOrCopy`.
    private func open(_ link: String) {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url) { opened in
            if !opened { UIPasteboard.general.string = link }
        }
    }
}

/// The context lines of a report, read once when the sheet opens.
struct SendFeedbackContext: Equatable {
    let platform: String
    let versions: String
    let environment: String
    let `where`: String
    let toggles: String

    @MainActor
    static func current() -> SendFeedbackContext {
        let config = SDKConfigManager.instance.sdkConfig
        return SendFeedbackContext(
            platform: "iOS \(UIDevice.current.systemVersion) · \(deviceModel)",
            versions: "\(OctopusCore.version) · sample \(SettingsView.sampleVersion) (\(SettingsView.sampleBuild))",
            environment: config.map(SampleConfigSummary.serverEnvironment) ?? "Demo",
            where: SampleTabRouter.instance.lastContentBreadcrumb,
            toggles: FeatureToggles.instance.summaryLine)
    }

    /// The hardware identifier ("iPhone17,3"), the simulated one on a simulator: Android sends `Build.MODEL`.
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

/// Builds the `issues/new` URL, as Android's `issueUrl`: the platform and `spotted` labels, the context table and
/// the last 50 Debug console lines, everything user-supplied redacted, the whole kept under `maxURLLength`.
enum SendFeedbackURL {
    /// How many Debug console lines ride along.
    static let logLines = 50

    /// GitHub answers `issues/new?body=` above roughly 8 KB with an error page, and the report is lost with it.
    static let maxURLLength = 7000

    /// The log gives way first, oldest line first, with a marker saying how many were dropped; the comment is cut
    /// only if the log alone was not enough, and says so. The failure mode is a shorter report, never none.
    static func issueURL(repo: String, context: SendFeedbackContext, comment: String,
                         debugLog: [DebugEntry]) -> String {
        var lines = debugLog.suffix(logLines).map { redact("\($0.category.label)  \($0.summary)") }
        var dropped = 0
        var text = redact(comment)
        var commentCut = false

        func build() -> String {
            var body = "### What happened\n\n"
            body += (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "_(no description)_" : text)
                + "\n"
            if commentCut { body += "\n_(comment truncated to fit the issue URL)_\n" }
            body += "\n### Context\n\n| | |\n|---|---|\n"
            body += "| Platform | \(context.platform) |\n"
            body += "| SDK | \(context.versions) |\n"
            body += "| Environment | \(redact(context.environment)) |\n"
            body += "| Where | \(context.where) |\n"
            body += "| Feature toggles | \(context.toggles) |\n"
            body += "\n### Debug console (last \(logLines) lines, redacted)\n\n```\n"
            if dropped > 0 { body += "… \(dropped) older lines dropped to fit the issue URL\n" }
            lines.forEach { body += $0 + "\n" }
            body += "```\n"
            return "https://github.com/\(repo)/issues/new"
                + "?labels=\(encode("ios,spotted"))"
                + "&title=\(encode("[Sample] \(context.where)"))"
                + "&body=\(encode(body))"
        }

        var url = build()
        while url.count > maxURLLength && !lines.isEmpty {
            lines.removeFirst()
            dropped += 1
            url = build()
        }
        while url.count > maxURLLength && text.count > 200 {
            // `prefix` counts characters, so a cut never splits an emoji, unlike Kotlin's `take`.
            text = String(text.prefix(text.count * 3 / 4))
            commentCut = true
            url = build()
        }
        return url
    }

    /// Masks anything key-shaped: a JWT, then any 24+ character token. Greedy on purpose, as on Android.
    static func redact(_ text: String) -> String {
        text.replacingOccurrences(of: #"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+"#, with: "***",
                                  options: .regularExpression)
            .replacingOccurrences(of: #"\b[A-Za-z0-9_-]{24,}\b"#, with: "***", options: .regularExpression)
    }

    /// Percent-encodes a query value as Android's `Uri.encode`: everything but unreserved characters.
    static func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
                                       + "-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
