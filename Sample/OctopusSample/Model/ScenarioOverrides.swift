//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

/// What the Scenarios screens last applied to the SDK, for their "Override active" badges and for the live config
/// card. The SDK exposes no getter for these overrides, so the Sample remembers what it sent.
///
/// A community switch rebuilds the SDK core and drops every debug override with it, so the record is cleared on
/// `.apiKeyChanged`.
@MainActor
final class ScenarioOverrides: ObservableObject {
    static let instance = ScenarioOverrides()

    /// Profile fields lock applied, `nil` for the backend value.
    @Published private(set) var profileFieldsLock: ProfileFieldsLock?
    /// Content options applied, `nil` for the backend value.
    @Published private(set) var contentOptions: ContentOptions?
    /// Terms acceptance mode applied, `nil` for the backend value.
    @Published private(set) var termsAcceptance: TermsAcceptanceMode?
    /// Consent texts applied, `nil` for the backend value.
    @Published private(set) var consentTexts: ConsentTexts?
    /// Force nickname choice applied, `nil` for the backend value.
    @Published private(set) var forceNicknameChoice: Bool?
    /// Last value `overrideCommunityAccess` accepted, shared by the community access and A/B scenarios as on
    /// Android. The call has no reset, so this stays set until a community switch.
    @Published var communityAccess: Bool?

    private var storage = [AnyCancellable]()

    init(notificationCenter: NotificationCenter = .default) {
        notificationCenter.publisher(for: .apiKeyChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.clear() }
            .store(in: &storage)
    }

    func apply(profileFieldsLock lock: ProfileFieldsLock?, octopus: OctopusSDK? = nil) {
        (octopus ?? OctopusSDKProvider.instance.octopus).debugOverrideProfileFieldsLock(lock)
        profileFieldsLock = lock
    }

    func apply(contentOptions options: ContentOptions?, octopus: OctopusSDK? = nil) {
        (octopus ?? OctopusSDKProvider.instance.octopus).debugOverrideContentOptions(options)
        contentOptions = options
    }

    func apply(termsAcceptance mode: TermsAcceptanceMode?, octopus: OctopusSDK? = nil) {
        (octopus ?? OctopusSDKProvider.instance.octopus).debugOverrideTermsAcceptanceMode(mode)
        termsAcceptance = mode
    }

    func apply(consentTexts texts: ConsentTexts?, octopus: OctopusSDK? = nil) {
        (octopus ?? OctopusSDKProvider.instance.octopus).debugOverrideConsentTexts(texts)
        consentTexts = texts
    }

    func apply(forceNicknameChoice enabled: Bool?, octopus: OctopusSDK? = nil) {
        (octopus ?? OctopusSDKProvider.instance.octopus).debugOverrideForceNicknameChoice(enabled)
        forceNicknameChoice = enabled
    }

    func clear() {
        profileFieldsLock = nil
        contentOptions = nil
        termsAcceptance = nil
        consentTexts = nil
        forceNicknameChoice = nil
        communityAccess = nil
    }
}

/// The labels the override scenarios and the live config card render, worded as on Android.
enum OverrideLabels {
    static let backendDefault = "none (backend default)"

    static func tick(_ enabled: Bool) -> String { enabled ? "✓ on" : "✗ off" }

    static func lock(_ state: ProfileFieldLockState) -> String {
        switch state {
        case .editable: "editable"
        case .readOnly: "read-only"
        case .disabled: "hidden"
        }
    }

    /// The profile fields lock preset's own label, as the scenario's result line shows it.
    static func lockLabel(_ lock: ProfileFieldsLock) -> String {
        guard lock != .allEditable else { return "All editable (default / no-op)" }
        return "nickname=\(raw(lock.nickname)), avatar=\(raw(lock.avatar)), bio=\(raw(lock.bio))"
    }

    /// One line per field, as the live config card shows it.
    static func lockLine(_ lock: ProfileFieldsLock) -> String {
        "nickname \(self.lock(lock.nickname)) · avatar \(self.lock(lock.avatar)) · bio \(self.lock(lock.bio))"
    }

    /// The content options presets, in the scenario's order, with the label each one renders.
    static let contentOptionsPresets: [(label: String, options: ContentOptions)] = {
        let all = ContentOptions.allEnabled
        return [
            ("All enabled (default / no-op)", all),
            ("Post: pictures off",
             ContentOptions(post: .init(enablePictures: false, enablePolls: true), comment: all.comment,
                            reply: all.reply)),
            ("Post: polls off",
             ContentOptions(post: .init(enablePictures: true, enablePolls: false), comment: all.comment,
                            reply: all.reply)),
            ("Post: pictures + polls off",
             ContentOptions(post: .init(enablePictures: false, enablePolls: false), comment: all.comment,
                            reply: all.reply)),
            ("Comment: pictures off",
             ContentOptions(post: all.post, comment: .init(enablePictures: false), reply: all.reply)),
            ("Reply: pictures off",
             ContentOptions(post: all.post, comment: all.comment, reply: .init(enablePictures: false))),
            ("Post: text optional with an image",
             ContentOptions(post: .init(enablePictures: true, enablePolls: true, textRequired: false),
                            comment: all.comment, reply: all.reply)),
        ]
    }()

    static func contentOptionsLabel(_ options: ContentOptions) -> String {
        if let preset = contentOptionsPresets.first(where: { $0.options == options }) { return preset.label }
        return "post pictures=\(options.post.enablePictures), polls=\(options.post.enablePolls), " +
            "textRequired=\(options.post.textRequired), comment pictures=\(options.comment.enablePictures), " +
            "reply pictures=\(options.reply.enablePictures)"
    }

    static func termsLabel(_ mode: TermsAcceptanceMode) -> String {
        switch mode {
        case .implicit: "implicit"
        case .explicitMultiCheckbox: "explicit · multi checkbox"
        case .explicitSingleCheckbox: "explicit · single checkbox"
        }
    }

    /// The live config card's wording, which names the implicit mode's legal footer.
    static func termsLine(_ mode: TermsAcceptanceMode) -> String {
        mode == .implicit ? "implicit (legal footer)" : termsLabel(mode)
    }

    private static func raw(_ state: ProfileFieldLockState) -> String {
        switch state {
        case .editable: "EDITABLE"
        case .readOnly: "READ_ONLY"
        case .disabled: "DISABLED"
        }
    }
}
