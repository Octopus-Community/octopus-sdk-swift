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
