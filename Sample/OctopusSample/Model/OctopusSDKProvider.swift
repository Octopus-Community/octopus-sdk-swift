//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
@_spi(OctopusInternalTesting) import Octopus

/// This class is a singleton that provides an instance of the Octopus SDK.
///
/// To test with your own API Key, you will need to modify the way to init the SDK accordingly to your community
/// configuration in the function `initializeSDK()`
class OctopusSDKProvider: ObservableObject {

    static let instance = OctopusSDKProvider()

    /// Whether the singleton has been built. Read without touching `instance`, so a caller can apply a
    /// debug setting to a live SDK without forcing one into existence before a config is set — that
    /// path is a fatal error on a first launch.
    private(set) static var isCreated = false

    /// Applies the config screen's debug switches to the SDK, if there is one yet.
    static func applyDebugSettingsIfLoaded() {
        guard isCreated else { return }
        instance.applyForcedConnectivity()
    }

    private(set) var octopus: OctopusSDK! {
        didSet { octopusInstanceDidChange() }
    }
    @Published var clientLoginRequired = false
    @Published var clientModifyUserField: ConnectionMode.SSOConfiguration.ProfileField?
    @Published var clientModifyUserAsked = false
    /// Feature env currently applied, `nil` when the Sample runs on its default community.
    @Published private(set) var currentFeatureEnv: FeatureEnvSelection?
    /// Set at launch when a persisted selection was dropped (expired, or unusable host).
    @Published private(set) var featureEnvDroppedAtLaunch: FeatureEnvSelection?

    private var storage = [AnyCancellable]()

    /// Whether a community switch is running, from the moment its caller starts persisting a new
    /// configuration until the SDK has been rebuilt on it.
    ///
    /// Two switches at once tear the SDK down and rebuild it twice over the same objects, which is what
    /// `switchCommunity` documents as unsupported and what corrupted the tracking session (a use-after-free
    /// on the session heartbeat timer). Overlapping them also crosses their configuration writes, leaving
    /// the persisted config describing a community the SDK is not running on. The screens disable their
    /// buttons while a switch runs, but that is not enough on its own: the launch-argument path
    /// (`applyFeatureEnvFromLaunchArgumentIfNeeded`) switches without any UI, and the two screens do not
    /// know about each other.
    ///
    /// Only ever touched on the main actor, which is what makes checking it and setting it one atomic step.
    /// The switch itself does not run on the main thread: `switchCommunity` is not main-isolated, so
    /// awaiting it leaves the main actor.
    @MainActor private var isSwitchingCommunity = false

    private init() {
        Self.isCreated = true
        initializeSDK()
    }

    /// Rebuilds the SDK on the currently persisted configuration. Refused while another switch is running,
    /// see `isSwitchingCommunity`.
    @MainActor
    func switchCommunityFromConfig() async throws {
        guard !isSwitchingCommunity else { throw CommunitySwitchError.alreadyInProgress }
        isSwitchingCommunity = true
        defer { isSwitchingCommunity = false }

        try await performSwitchFromConfig()
    }

    /// The switch itself, without the guard.
    /// - Important: only call from a caller that has taken `isSwitchingCommunity`.
    @MainActor
    private func performSwitchFromConfig() async throws {
        let initializationData = sdkInitializationDataFromConfig()
        printSdkCreation(connectionMode: initializationData.connectionMode)
        try await octopus.switchCommunity(apiKey: initializationData.apiKey,
                                          connectionMode: initializationData.connectionMode,
                                          configuration: initializationData.configuration)
    }

    /// Applies (or clears) a feature env and rebuilds the SDK on it. Refused while another switch is
    /// running, see `isSwitchingCommunity`.
    ///
    /// Rolls the persisted selection back when the switch fails, so the app never relaunches on an env
    /// it could not reach.
    @MainActor
    func apply(featureEnv selection: FeatureEnvSelection?) async throws {
        // Refused before anything is persisted. Otherwise the selection is stored, `resolveFeatureEnv`
        // drops it as expired at build time, the switch to the *default* community succeeds, and the
        // success path clears the only notice explaining the fallback — so the developer sees no error
        // and believes they are on the env.
        if let selection, selection.isExpired() {
            throw FeatureEnvApplyError.expired(selection)
        }
        // Taken here and not around `performSwitchFromConfig()` alone: `previous` is read from the
        // persisted config and written back on failure, so a second `apply` slipping between that read and
        // the switch would roll back to *its* selection and leave the persisted config describing a
        // community the SDK is not running on.
        guard !isSwitchingCommunity else { throw CommunitySwitchError.alreadyInProgress }
        isSwitchingCommunity = true
        defer { isSwitchingCommunity = false }

        let previous = SDKConfigManager.instance.sdkConfig?.featureEnv
        SDKConfigManager.instance.setFeatureEnv(selection)
        do {
            try await performSwitchFromConfig()
            // The developer has just chosen where to run: whatever was dropped at launch is history, and
            // keeping the notice around would describe an env that is no longer the one in use.
            featureEnvDroppedAtLaunch = nil
            // `switchCommunity` mutates the same `OctopusSDK` object, so `octopus`'s `didSet` never
            // fires and nothing downstream knows the community changed. Same notification as
            // `SwitchCommunityViewModel`: `SampleTabView` re-`id`s the tree (rebuilding
            // `OctopusHomeScreen`, as the SDK's own `switchCommunity` doc requires) and `AppUserManager`
            // reconnects the user. Without it the community UI keeps rendering the previous community.
            NotificationCenter.default.post(name: .apiKeyChanged, object: nil)
        } catch {
            SDKConfigManager.instance.setFeatureEnv(previous)
            currentFeatureEnv = previous
            throw error
        }
    }

    /// Marks the "dropped at launch" notice as seen, so it does not come back every time the scenario is
    /// opened during the same session.
    func acknowledgeFeatureEnvDropped() {
        featureEnvDroppedAtLaunch = nil
    }

    /// Applies the feature env asked for at launch via `-featureEnvTicket`, if any.
    ///
    /// The ticket has to be resolved against the directory, which needs the network, so the app starts on
    /// its persisted configuration and switches once the answer arrives. Anything that goes wrong is
    /// logged and leaves the app on that configuration — QA tooling reads the console, and a silent
    /// half-switch would be worse than an explicit "stayed on the default".
    func applyFeatureEnvFromLaunchArgumentIfNeeded() {
        guard let ticket = DefaultValuesProvider.featureEnvTicketArgument else { return }
        guard DefaultValuesProvider.featureEnvsConfigured else {
            print("-featureEnvTicket \(ticket) ignored: feature envs are not configured in secrets.xcconfig")
            return
        }
        Task {
            do {
                let envs = try await FeatureEnvsDirectory.fetch()
                guard let selection = FeatureEnvSelection.resolve(
                    ticket: ticket,
                    communityHint: DefaultValuesProvider.featureEnvCommunityArgument,
                    in: envs) else {
                    print("-featureEnvTicket \(ticket): no live env matches, staying on the current community")
                    return
                }
                try await apply(featureEnv: selection)
                print("-featureEnvTicket \(ticket): now on \(selection.displayName) · \(selection.communityName)")
            } catch let error as FeatureEnvsError {
                // `userMessage`, not `\(error)`: interpolating the wrapped `URLError` prints its
                // userInfo, which contains the failing URL — token and all. This is the QA-tooling path,
                // whose console output is captured into reports and CI logs.
                print("-featureEnvTicket \(ticket) failed: \(error.userMessage)")
            } catch {
                print("-featureEnvTicket \(ticket) failed: \(error.localizedDescription)")
            }
        }
    }

    /// Applies the config screen's "act as if offline" switch to the current SDK instance.
    ///
    /// Done here rather than at the call site: the instance is recreated on a config change or a
    /// community switch, and the override has to survive that — otherwise the screen states would be
    /// offline until the first switch and online after it.
    private func applyForcedConnectivity() {
        let forceOffline = SampleDebugSettings.forceOffline
        guard let octopus else { return }
        // The override is main-actor isolated, like the SDK's other debug affordances.
        Task { @MainActor in
            octopus.debugOverrideConnectionAvailable(forceOffline ? false : nil)
        }
    }

    private func octopusInstanceDidChange() {
        storage = []
        applyForcedConnectivity()

        NotificationManager.instance.$notificationDeviceToken
            .sink { [unowned self] notificationDeviceToken in
                guard let notificationDeviceToken else { return }
                print("Setting notification device token to octopus SDK")
                octopus.set(notificationDeviceToken: notificationDeviceToken)
            }.store(in: &storage)

        TrackingManager.instance.set(octopus: octopus)
        URLManager.instance.set(octopus: octopus)
        GroupAccessDeniedManager.instance.set(octopus: octopus)
        ClientProfileManager.instance.set(octopus: octopus)
    }

    private func initializeSDK() {
        guard !DefaultValuesProvider.internalDemoMode else {
            // only used for internal demo mode, please ignore
            initializeSDKForInternalUsage()
            return
        }

        // MODIFY THE FOLLOWING CODE TO MATCH YOUR COMMUNITY CONFIGURATION:
        initializeSdkInSSOWithNoFieldsAssociated()
        // initializeSdkInSSOFullAssociated()
        // initializeSdkInSSOWithSomeFieldsAssociated
        // initializeSdkWithOctopusAuth
    }

    /// Initialize the Octopus SDK in SSO with all fields that are app managed (i.e. fully associated)
    private func initializeSdkInSSOFullAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                appManagedFields: Set(ConnectionMode.SSOConfiguration.ProfileField.allCases),
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }, modifyUser: { [weak self] in
                    self?.clientModifyUserField = $0
                    self?.clientModifyUserAsked = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in SSO with some fields that are app managed (i.e. associated)
    private func initializeSdkInSSOWithSomeFieldsAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                appManagedFields: [.nickname, .picture], // EDIT THE ASSOCIATED FIELDS HERE
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }, modifyUser: { [weak self] in
                    self?.clientModifyUserField = $0
                    self?.clientModifyUserAsked = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in SSO with no app managed fields (i.e. SSO Dissociated)
    private func initializeSdkInSSOWithNoFieldsAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in Octopus auth (i.e. authentification will be done with a MagicLink)
    private func initializeSdkWithOctopusAuth() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .octopus(deepLink: nil) // EDIT THE DEEPLINK IF YOU WANT TO
        )
    }

    private func initializeSDKForInternalUsage() {
        let initializationData = sdkInitializationDataFromConfig()
        printSdkCreation(connectionMode: initializationData.connectionMode)
        octopus = try! OctopusSDK(apiKey: initializationData.apiKey,
                                  connectionMode: initializationData.connectionMode,
                                  configuration: initializationData.configuration)
    }

    private func sdkInitializationDataFromConfig()
    -> (apiKey: String, connectionMode: ConnectionMode, configuration: OctopusSDK.Configuration) {
        guard let sdkConfig = SDKConfigManager.instance.sdkConfig else {
            fatalError("SDK config should be set before initializing the SDK")
        }
        let featureEnvData = resolveFeatureEnv(sdkConfig.featureEnv)
        let connectionMode: ConnectionMode = switch sdkConfig.authKind {
        case .octopus: .octopus(deepLink: "com.octopuscommunity.sample://magic-link")
        case let .sso(appManagedFields, _):
                .sso(
                    .init(
                        appManagedFields: Set(appManagedFields.map {
                            return switch $0 {
                            case .nickname: .nickname
                            case .bio: .bio
                            case .picture: .picture
                            }
                        }), loginRequired: { [weak self] in
                            self?.clientLoginRequired = true
                        }, modifyUser: { [weak self] in
                            self?.clientModifyUserField = $0
                            self?.clientModifyUserAsked = true
                        }
                    )
                )
        }
        let apiKey = switch sdkConfig.authKind {
        case .octopus: APIKeys.octopusAuth
        case let .sso(appManagedFields, forceLoginOnStrongActions):
            if appManagedFields.isEmpty {
                if forceLoginOnStrongActions {
                    APIKeys.ssoNoManagedFieldsForceLogin
                } else {
                    APIKeys.ssoNoManagedFields
                }
            } else if Set(appManagedFields) == Set(SDKConfig.ProfileField.allCases) {
                APIKeys.ssoAllManagedFields
            } else {
                APIKeys.ssoSomeManagedFields
            }
        }
        return (apiKey: featureEnvData.selection?.apiKey ?? apiKey,
                connectionMode: connectionMode,
                configuration: OctopusSDK.Configuration(apiServer: featureEnvData.apiServer))
    }

    /// Decides whether a persisted feature env can still be used, and publishes the outcome.
    ///
    /// Two reasons to drop it, both checked without any network call: it expired (thanks to the stored
    /// `expiresAt`), or its host cannot produce a valid endpoint. In both cases the stored selection is
    /// cleared so the next launch starts clean, and `featureEnvDroppedAtLaunch` lets the UI explain why.
    private func resolveFeatureEnv(_ persisted: FeatureEnvSelection?)
    -> (selection: FeatureEnvSelection?, apiServer: OctopusSDK.Configuration.ApiServer?) {
        guard let persisted else {
            currentFeatureEnv = nil
            return (nil, nil)
        }
        if persisted.isExpired() {
            print("Feature env \(persisted.displayName) expired, falling back to the default community")
            dropFeatureEnv(persisted)
            return (nil, nil)
        }
        guard let apiServer = persisted.apiServer() else {
            dropFeatureEnv(persisted)
            return (nil, nil)
        }
        currentFeatureEnv = persisted
        return (persisted, apiServer)
    }

    private func dropFeatureEnv(_ selection: FeatureEnvSelection) {
        SDKConfigManager.instance.setFeatureEnv(nil)
        currentFeatureEnv = nil
        featureEnvDroppedAtLaunch = selection
    }

    private func printSdkCreation(connectionMode: ConnectionMode) {
        switch connectionMode {
        case .octopus: print("Create SDK with connection mode: Octopus")
        case let .sso(config):
            if config.appManagedFields.isEmpty {
                print("Create SDK with connection mode: SSO with no app managed fields")
            } else if config.appManagedFields == Set(ConnectionMode.SSOConfiguration.ProfileField.allCases) {
                print("Create SDK with connection mode: SSO with all managed fields")
            } else {
                print("Create SDK with connection mode: SSO with some managed fields")
            }
        }
    }
}

/// Why a community switch was refused. `LocalizedError` so the view models' `error.localizedDescription`
/// carries the explanation instead of a type name.
enum CommunitySwitchError: LocalizedError {
    case alreadyInProgress

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "A community switch is already running. Wait for it to finish before starting another one."
        }
    }
}
