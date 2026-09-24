//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// View model of the SDKConfigView. Internal use only.
@MainActor
class SDKConfigViewModel: ObservableObject {
    enum AuthMode {
        case octopus
        case sso
    }

    @Published var authMode: AuthMode = .sso
    @Published var nicknameIsAssociated = false
    @Published var bioIsAssociated = false
    @Published var pictureIsAssociated = false
    @Published var forceLoginOnStringAction = false
    @Published var canSave = false
    /// Debug: what the SDK believes about connectivity. Stored here rather than read from the SDK
    /// provider — touching the provider would build the SDK before a config exists, which is fatal on
    /// a first launch.
    @Published var forceOffline = SampleDebugSettings.forceOffline

    private var storage = [AnyCancellable]()

    init() {
        Publishers.CombineLatest4(
            $authMode,
            $nicknameIsAssociated,
            $bioIsAssociated,
            $pictureIsAssociated
        ).sink { [unowned self] authMode, nicknameIsAssociated, bioIsAssociated, pictureIsAssociated in
            switch authMode {
            case .sso:
                switch (nicknameIsAssociated, bioIsAssociated, pictureIsAssociated) {
                case (true, true, true),
                    (false, false, false),
                    (true, false, _):
                    canSave = true
                default: canSave = false

                }
            case .octopus: canSave = true
            }

        }.store(in: &storage)
    }

    func setForceOffline(_ forceOffline: Bool) {
        self.forceOffline = forceOffline
        SampleDebugSettings.forceOffline = forceOffline
        // Applies to a live SDK when there is one, and is picked up at creation otherwise.
        OctopusSDKProvider.applyDebugSettingsIfLoaded()
    }

    func save() {
        switch authMode {
        case .octopus:
            SDKConfigManager.instance.set(config: .init(authKind: .octopus))
        case .sso:
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
            SDKConfigManager.instance.set(config: SDKConfig(
                authKind: .sso(appManagedFields: appManagedFields,
                               forceLoginOnStrongActions: forceLoginOnStringAction)))
        }
    }
}
