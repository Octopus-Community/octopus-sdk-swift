//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// One of the four SSO keys of the demo community, in the order Configuration › Community lists them (the same
/// order as the Android and Flutter samples). The key itself comes from the build (Info.plist), never from here.
struct AuthPreset: Identifiable, Equatable {
    let id: String
    let label: String
    /// The force-login position this preset applies to the Configuration screen.
    let forceLogin: Bool
    /// The managed fields this preset applies when picked. Any other non-empty, partial set resolves to the
    /// "some managed fields" key as well.
    let managedFields: [SDKConfig.ProfileField]

    static let noManagedNoForced = AuthPreset(id: "ssoNoManagedNoForced",
                                              label: "SSO · no managed fields · no forced login",
                                              forceLogin: false, managedFields: [])
    static let noManagedForced = AuthPreset(id: "ssoNoManagedForced",
                                            label: "SSO · no managed fields · forced login",
                                            forceLogin: true, managedFields: [])
    static let allManagedForced = AuthPreset(id: "ssoAllManagedForced",
                                             label: "SSO · all managed fields · forced login",
                                             forceLogin: true, managedFields: SDKConfig.ProfileField.allCases)
    static let someManagedForced = AuthPreset(id: "ssoSomeManagedForced",
                                              label: "SSO · some managed fields · forced login",
                                              forceLogin: true, managedFields: [.nickname, .picture])

    static let all = [noManagedNoForced, noManagedForced, allManagedForced, someManagedForced]

    /// The build's key for this preset. Shown masked only.
    var key: String {
        switch id {
        case Self.noManagedForced.id: APIKeys.ssoNoManagedFieldsForceLogin
        case Self.allManagedForced.id: APIKeys.ssoAllManagedFields
        case Self.someManagedForced.id: APIKeys.ssoSomeManagedFields
        default: APIKeys.ssoNoManagedFields
        }
    }

    /// The preset an auth shape resolves to: the key-derivation rule. With managed fields, force login does not
    /// change the key (the demo community only has forced-login keys for managed fields).
    static func resolve(forceLogin: Bool, managedFields: [SDKConfig.ProfileField]) -> AuthPreset {
        let fields = Set(managedFields)
        if fields.isEmpty { return forceLogin ? noManagedForced : noManagedNoForced }
        if fields == Set(SDKConfig.ProfileField.allCases) { return allManagedForced }
        return someManagedForced
    }

    static func resolve(_ authKind: SDKConfig.AuthKind) -> AuthPreset {
        switch authKind {
        case let .sso(appManagedFields, forceLoginOnStrongActions):
            resolve(forceLogin: forceLoginOnStrongActions, managedFields: appManagedFields)
        }
    }

    /// Whether the demo community has a key for these managed fields. Only these shapes exist on the demo
    /// backend: none, all, or nickname without bio.
    static func hasDemoCommunity(managedFields: [SDKConfig.ProfileField]) -> Bool {
        let fields = Set(managedFields)
        return fields.isEmpty || fields == Set(SDKConfig.ProfileField.allCases)
            || (fields.contains(.nickname) && !fields.contains(.bio))
    }
}

/// The SSO user ids offered as chips on Configuration › Connect your users (SSO): stable test identities, not
/// secrets. The first one names this sample's platform, the two QA ids are shared with the Android sample so two
/// devices can hold distinct users.
enum SampleUserIds {
    static let predefined = ["ios-sample-user", "qa-tester-ios", "qa-tester-android"]

    /// The chips: the predefined ids, then the stored id when it is a custom one typed on Settings › Account.
    /// Trimmed, empty values dropped, duplicates removed in first-seen order.
    static func picker(storedUserId: String?) -> [String] {
        var seen = Set<String>()
        return (predefined + [storedUserId ?? ""])
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

/// The one-line descriptions of a configuration that Settings, Configuration and Apply show, worded as the
/// Android sample's `SampleConfigSummary`.
enum SampleConfigSummary {
    /// "Demo", "Prod", "Custom" or "Feature env · <ticket>".
    static func serverEnvironment(_ config: SDKConfig) -> String {
        if let env = config.featureEnv { return "Feature env · \(env.displayName)" }
        guard let server = config.customServer else { return "Demo" }
        return server.isProd ? "Prod" : "Custom"
    }

    /// The community the configuration opens.
    static func community(_ config: SDKConfig) -> String {
        if let env = config.featureEnv { return env.communityName }
        return config.customApiKey == nil ? "Demo community" : "Custom community"
    }

    /// Where the API key comes from, the key masked: "Demo preset · SSO · …", "Custom · abcd…wxyz".
    static func apiKeySource(_ config: SDKConfig) -> String {
        if let env = config.featureEnv { return "Feature env · \(ScenarioCatalog.maskApiKey(env.apiKey))" }
        if let key = config.customApiKey { return "Custom · \(ScenarioCatalog.maskApiKey(key))" }
        return "Demo preset · \(AuthPreset.resolve(config.authKind).label)"
    }

    /// The key the SDK is built with: the feature env's, else the custom one, else the preset's.
    static func resolvedApiKey(_ config: SDKConfig, featureEnv: FeatureEnvSelection?) -> String {
        featureEnv?.apiKey ?? config.customApiKey ?? AuthPreset.resolve(config.authKind).key
    }

    /// What Apply or Start SDK is about to do, in one line, so the tap is never silent. `persisted` is `nil` on
    /// the first start. Every `SDKConfig` field changes the key, the server or the connection mode, so any
    /// difference rebuilds the SDK; the theme and appearance live outside it and apply without a restart.
    static func applyOutcome(persisted: SDKConfig?, next: SDKConfig, userChanged: Bool,
                             appearanceChanged: Bool) -> String {
        let target = apiKeySource(next)
        guard let persisted else { return "Starting the SDK · \(target)" }
        if persisted != next { return "Applied · restarting the SDK on \(target)" }
        if userChanged { return "Applied · connecting the new user, no SDK restart needed" }
        if appearanceChanged { return "Applied · no SDK restart needed" }
        return "Nothing to apply · the configuration is unchanged"
    }
}

extension SDKConfig.CustomServer {
    /// The SDK endpoint for this host, or `nil` when the SDK refuses it (empty, a scheme, a path, whitespace).
    func apiServer() -> OctopusSDK.Configuration.ApiServer? {
        do {
            return try OctopusSDK.Configuration.ApiServer(host: host, port: port)
        } catch {
            print("Custom server '\(host)' refused (\(error)), using the default server")
            return nil
        }
    }
}
