//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// View model of the SDKConfigView. Internal use only.
@MainActor
class SDKConfigViewModel: ObservableObject {
    @Published var nicknameIsAssociated: Bool
    @Published var bioIsAssociated: Bool
    @Published var pictureIsAssociated: Bool
    @Published var forceLoginOnStringAction: Bool
    @Published var canSave = false
    /// Debug: what the SDK believes about connectivity. Stored here rather than read from the SDK
    /// provider — touching the provider would build the SDK before a config exists, which is fatal on
    /// a first launch.
    @Published var forceOffline = SampleDebugSettings.forceOffline
    /// The Unified Profile state applied to the SDK right now, which the Config line describes.
    @Published private(set) var unifiedProfile: UnifiedProfileHostState

    /// The persisted config, `nil` on a first launch. Read again on save: its feature env is not edited here, and
    /// the Feature envs scenario may have changed it while this screen stayed open.
    private let savedConfig: () -> SDKConfig?
    private let unifiedProfileManager: UnifiedProfileManager
    private var storage = [AnyCancellable]()

    /// - Parameters:
    ///   - savedConfig: the persisted config. The fields start from it, so the screen shows what the SDK runs on.
    ///   - unifiedProfileManager: where the Unified Profile switch is applied and persisted, `instance` when `nil`
    ///     (resolved here: a default argument is not evaluated on the main actor).
    init(savedConfig: @escaping () -> SDKConfig? = { SDKConfigManager.instance.sdkConfig },
         unifiedProfileManager: UnifiedProfileManager? = nil) {
        let unifiedProfileManager = unifiedProfileManager ?? .instance
        self.savedConfig = savedConfig
        self.unifiedProfileManager = unifiedProfileManager
        unifiedProfile = unifiedProfileManager.state

        switch savedConfig()?.authKind {
        case let .sso(appManagedFields, forceLoginOnStrongActions):
            nicknameIsAssociated = appManagedFields.contains(.nickname)
            bioIsAssociated = appManagedFields.contains(.bio)
            pictureIsAssociated = appManagedFields.contains(.picture)
            forceLoginOnStringAction = forceLoginOnStrongActions
        case nil:
            nicknameIsAssociated = false
            bioIsAssociated = false
            pictureIsAssociated = false
            forceLoginOnStringAction = false
        }

        Publishers.CombineLatest3(
            $nicknameIsAssociated,
            $bioIsAssociated,
            $pictureIsAssociated
        ).sink { [unowned self] nicknameIsAssociated, bioIsAssociated, pictureIsAssociated in
            switch (nicknameIsAssociated, bioIsAssociated, pictureIsAssociated) {
            case (true, true, true),
                (false, false, false),
                (true, false, _):
                canSave = true
            default: canSave = false
            }
        }.store(in: &storage)

        unifiedProfileManager.$state
            .sink { [unowned self] in unifiedProfile = $0 }
            .store(in: &storage)
    }

    func setForceOffline(_ forceOffline: Bool) {
        self.forceOffline = forceOffline
        SampleDebugSettings.forceOffline = forceOffline
        // Applies to a live SDK when there is one, and is picked up at creation otherwise.
        OctopusSDKProvider.applyDebugSettingsIfLoaded()
    }

    /// The Unified Profile switch: applied and persisted at once, like the offline switch, without a save.
    func setUnifiedProfileEnabled(_ isOn: Bool) {
        unifiedProfileManager.setEnabled(isOn)
    }

    /// The config the fields describe, keeping the saved feature env: a save from this screen must not move the
    /// SDK off the env it targets.
    func makeConfig() -> SDKConfig {
        var appManagedFields: [SDKConfig.ProfileField] = []
        if nicknameIsAssociated {
            appManagedFields.append(.nickname)
        }
        if bioIsAssociated {
            appManagedFields.append(.bio)
        }
        if pictureIsAssociated {
            appManagedFields.append(.picture)
        }
        return SDKConfig(
            authKind: .sso(appManagedFields: appManagedFields,
                           forceLoginOnStrongActions: forceLoginOnStringAction),
            featureEnv: savedConfig()?.featureEnv)
    }

    func save() {
        SDKConfigManager.instance.set(config: makeConfig())
    }
}
