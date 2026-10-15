//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// Configuration, mirroring the Android sample's `ConfigViewModel`: the server, the community (a demo preset or a
/// pasted key), the SSO user and the theme, edited as a draft and applied together by Start SDK or Apply.
/// Internal demo mode only.
@MainActor
final class ConfigViewModel: ObservableObject {
    enum ServerKind: Equatable {
        case demo
        case prod
        case custom
        case featureEnv
    }

    /// `true` from Settings › Configuration (the button reads "Apply"), `false` on a first start ("Start SDK").
    let isRevisit: Bool
    /// Whether the build carries the feature-env directory settings (gitignored `secrets.xcconfig`).
    let featureEnvsConfigured: Bool
    /// The SSO user chips: the stable test identities, then a custom stored id.
    let pickerUserIds: [String]

    @Published var serverKind: ServerKind
    @Published var customHost: String
    @Published var customPort: String
    @Published private(set) var featureEnvs: [FeatureEnv] = []
    @Published private(set) var featureEnvsLoading = false
    @Published private(set) var featureEnvsLoaded = false
    @Published private(set) var featureEnvsError: String?
    @Published private(set) var selectedFeatureEnv: FeatureEnvSelection?

    @Published private(set) var useCustomCommunity: Bool
    @Published var customApiKey: String
    @Published private(set) var forceLogin: Bool
    @Published private(set) var managedFields: [SDKConfig.ProfileField]

    @Published var ssoUserId: String?
    @Published var appearance: SampleAppearance
    @Published var themePreset: SDKThemePreset
    /// Debug: what the SDK believes about connectivity, applied at once like on the former Config screen.
    @Published private(set) var forceOffline = SampleDebugSettings.forceOffline
    @Published private(set) var unifiedProfile: UnifiedProfileHostState
    /// What the last Apply did, shown under the button: iOS has no snackbar.
    @Published private(set) var outcome: String?

    private let savedConfig: () -> SDKConfig?
    private var storedUserId: String?
    private var storage = [AnyCancellable]()

    /// - Parameters:
    ///   - savedConfig: the persisted config, `nil` on a first start. Read again on Apply.
    ///   - storedUserId: the SSO user id saved on this device. Read from `AppUserStore`, never through
    ///     `AppUserManager`, which builds the SDK.
    ///   - unifiedProfile: the Unified Profile state the read-only line describes.
    init(isRevisit: Bool,
         savedConfig: @escaping () -> SDKConfig? = { SDKConfigManager.instance.sdkConfig },
         storedUserId: String? = AppUserStore().user?.userId,
         appearance: SampleAppearance = SampleAppearanceStore.instance.appearance,
         themePreset: SDKThemePreset = SampleAppearanceStore.instance.themePreset,
         featureEnvsConfigured: Bool = DefaultValuesProvider.featureEnvsConfigured,
         unifiedProfile: AnyPublisher<UnifiedProfileHostState, Never>? = nil) {
        self.isRevisit = isRevisit
        self.savedConfig = savedConfig
        self.storedUserId = storedUserId
        self.featureEnvsConfigured = featureEnvsConfigured
        self.appearance = appearance
        self.themePreset = themePreset
        pickerUserIds = SampleUserIds.picker(storedUserId: storedUserId)
        // A first start connects a demo user, as the Android sample does with the user its build seeds.
        ssoUserId = storedUserId ?? (isRevisit ? nil : SampleUserIds.predefined.first)

        let config = savedConfig()
        let preset = config.map { AuthPreset.resolve($0.authKind) } ?? .noManagedNoForced
        switch config?.authKind {
        case let .sso(fields, force)?:
            managedFields = fields
            forceLogin = force
        case nil:
            managedFields = preset.managedFields
            forceLogin = preset.forceLogin
        }
        useCustomCommunity = config?.customApiKey != nil
        customApiKey = config?.customApiKey ?? ""
        let isProd = config?.customServer?.isProd == true
        customHost = isProd ? "" : config?.customServer?.host ?? ""
        customPort = isProd ? "443" : config?.customServer.map { String($0.port) } ?? "443"
        selectedFeatureEnv = config?.featureEnv
        serverKind = if config?.featureEnv != nil {
            .featureEnv
        } else if isProd {
            .prod
        } else if config?.customServer != nil {
            .custom
        } else { .demo }

        let profile = unifiedProfile ?? UnifiedProfileManager.instance.$state.eraseToAnyPublisher()
        self.unifiedProfile = UnifiedProfileHostState.switched(false)
        profile.sink { [weak self] in self?.unifiedProfile = $0 }.store(in: &storage)
    }

    // MARK: - Server

    /// The feature-env radio shows when the build can read the directory, or when an env is already in use.
    var showsFeatureEnvOption: Bool { featureEnvsConfigured || selectedFeatureEnv != nil }

    var isDefaultServer: Bool { serverKind == .demo }

    /// What the non-default confirmation names, as on Android.
    var confirmTarget: String {
        switch serverKind {
        case .demo: "default"
        case .prod: "api.8pus.io (PROD)"
        case .custom: customHost.trimmingCharacters(in: .whitespaces).isEmpty ? "custom" : customHost
        case .featureEnv: "a backend feature env"
        }
    }

    func setServerKind(_ kind: ServerKind) {
        serverKind = kind
        if kind == .featureEnv && !featureEnvsLoaded { loadFeatureEnvs() }
    }

    func loadFeatureEnvs() {
        guard featureEnvsConfigured, !featureEnvsLoading else { return }
        featureEnvsLoading = true
        featureEnvsError = nil
        Task { await performLoad() }
    }

    private func performLoad() async {
        do {
            featureEnvs = try await FeatureEnvsDirectory.fetch().filter { $0.isUsable() }
            featureEnvsLoaded = true
        } catch {
            featureEnvsError = error.userMessage
        }
        featureEnvsLoading = false
    }

    func selectFeatureEnv(_ env: FeatureEnv, community: FeatureEnv.Community) {
        selectedFeatureEnv = FeatureEnvSelection(env: env, community: community)
    }

    // MARK: - Community

    var resolvedPreset: AuthPreset { AuthPreset.resolve(forceLogin: forceLogin, managedFields: managedFields) }

    /// The key source a picked feature env imposes, whatever the community choice below; `nil` otherwise.
    var featureEnvKeySource: String? {
        guard serverKind == .featureEnv, let selectedFeatureEnv else { return nil }
        return SampleConfigSummary.apiKeySource(SDKConfig(authKind: authKind, featureEnv: selectedFeatureEnv))
    }

    /// The Community header summary: the feature env's key, the custom key masked, or the preset label.
    var communitySummary: String {
        if let featureEnvKeySource { return featureEnvKeySource }
        if useCustomCommunity { return "Custom API key · \(ScenarioCatalog.maskApiKey(customApiKey))" }
        return resolvedPreset.label
    }

    /// Picks a preset: its auth shape, unless the current fields already resolve to it (so "some managed fields"
    /// keeps the subset in place).
    func applyAuthPreset(_ preset: AuthPreset) {
        if AuthPreset.resolve(forceLogin: preset.forceLogin, managedFields: managedFields).id != preset.id {
            managedFields = preset.managedFields
        }
        forceLogin = preset.forceLogin
        useCustomCommunity = false
    }

    func setUseCustomCommunity() {
        useCustomCommunity = true
    }

    // MARK: - SSO

    var authKind: SDKConfig.AuthKind {
        .sso(appManagedFields: managedFields, forceLoginOnStrongActions: forceLogin)
    }

    func toggleManagedField(_ field: SDKConfig.ProfileField) {
        if managedFields.contains(field) {
            managedFields.removeAll { $0 == field }
        } else {
            managedFields = SDKConfig.ProfileField.allCases.filter { managedFields.contains($0) || $0 == field }
        }
    }

    /// The line under the Unified Profile entry: which key the managed fields select.
    var unifiedProfileCommunityLine: String {
        if let featureEnvKeySource {
            return "Feature env: its key is used (\(featureEnvKeySource)). Managed fields change who owns the " +
                "profile. Unified Profile is tried from its dedicated scenario."
        }
        if useCustomCommunity {
            return "Custom API key: the key is kept. Managed fields change who owns the profile. " +
                "Try Unified Profile from its dedicated scenario."
        }
        return "Key: “\(resolvedPreset.label)”. The presets are keys on the same demo community; " +
            "changing managed fields may select another key when applied. " +
            "The Unified Profile scenario wires profile navigation and forces the flag while on."
    }

    // MARK: - Debug

    func setForceOffline(_ forceOffline: Bool) {
        self.forceOffline = forceOffline
        SampleDebugSettings.forceOffline = forceOffline
        OctopusSDKProvider.applyDebugSettingsIfLoaded()
    }

    // MARK: - Apply

    /// Why Apply is refused, `nil` when the draft can be applied.
    var applyBlocker: String? {
        switch serverKind {
        case .demo, .prod: break
        case .custom:
            if customServer?.apiServer() == nil { return "Enter a host and a port the SDK accepts" }
        case .featureEnv:
            if selectedFeatureEnv == nil { return "Pick a feature env community" }
        }
        if useCustomCommunity {
            if serverKind != .featureEnv && trimmedApiKey == nil { return "Paste an API key" }
        } else if serverKind != .featureEnv && !AuthPreset.hasDemoCommunity(managedFields: managedFields) {
            return "No existing community to match this configuration"
        }
        return nil
    }

    private var trimmedApiKey: String? {
        let key = customApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    private var customServer: SDKConfig.CustomServer? {
        let host = customHost.trimmingCharacters(in: .whitespaces)
        guard let port = Int(customPort.trimmingCharacters(in: .whitespaces)), (1...65_535).contains(port)
        else { return nil }
        return SDKConfig.CustomServer(host: host, port: port)
    }

    /// The config Apply persists: this screen owns the server, the key and the auth shape. The feature env is
    /// kept only in feature-env mode — leaving that mode means another endpoint was chosen.
    func makeConfig(persisted: SDKConfig?) -> SDKConfig {
        var config = persisted ?? SDKConfig(authKind: authKind)
        config.authKind = authKind
        config.customServer = switch serverKind {
        case .prod: .prod
        case .custom: customServer
        case .demo, .featureEnv: nil
        }
        config.featureEnv = serverKind == .featureEnv ? (selectedFeatureEnv ?? persisted?.featureEnv) : nil
        config.customApiKey = useCustomCommunity ? trimmedApiKey : nil
        return config
    }

    /// Persists the draft and starts or rebuilds what changed: the user before the config, so a rebuild
    /// reconnects the new one; the SDK only when its config changed; the theme without a restart.
    @discardableResult
    func apply() -> String {
        let persisted = savedConfig()
        let next = makeConfig(persisted: persisted)
        let appearanceStore = SampleAppearanceStore.instance
        let appearanceChanged = appearance != appearanceStore.appearance || themePreset != appearanceStore.themePreset
        let pickedUserId = ssoUserId
        let userChanged = pickedUserId != nil && pickedUserId != storedUserId
        let message = SampleConfigSummary.applyOutcome(persisted: persisted, next: next, userChanged: userChanged,
                                                       appearanceChanged: appearanceChanged)

        appearanceStore.set(appearance: appearance)
        appearanceStore.set(themePreset: themePreset)

        if userChanged, let pickedUserId {
            // A different SSO id is a different person: a fresh user, not the previous one's profile.
            let user = AppUser(userId: pickedUserId)
            if OctopusSDKProvider.isCreated {
                AppUserManager.instance.set(appUser: user)
            } else {
                // Before the SDK exists, `AppUserManager` would build it: store the user, and the SDK connects it
                // when it starts.
                AppUserStore().set(user: user)
            }
            storedUserId = pickedUserId
        }

        if persisted != next {
            SDKConfigManager.instance.set(config: next)
            if OctopusSDKProvider.isCreated {
                Task { @MainActor in
                    try? await OctopusSDKProvider.instance.switchCommunityFromConfig()
                    NotificationCenter.default.post(name: .apiKeyChanged, object: nil)
                }
            }
        }
        outcome = message
        return message
    }
}
