//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import Foundation

/// One host decision the SDK hands to the app, as Settings › Host app integration lists it. Same ids, names and
/// effect lines as the Android sample's `HostCallback`, so a tester reads the same screen on both platforms.
enum HostCallback: String, CaseIterable, Identifiable {
    case profile
    case profileEdit = "profile-edit"
    case login
    case clientObject = "client-object"
    case groupAccessDenied = "group-access-denied"

    var id: String { rawValue }

    /// The public doc's name for the use case.
    var docName: String {
        switch self {
        case .profile: return "Route profile taps to your own profile screen"
        case .profileEdit: return "App profile editor"
        case .login: return "Open your sign-in screen"
        case .clientObject: return "Handle taps on the content button"
        case .groupAccessDenied: return "Gate access to locked groups"
        }
    }

    /// The iOS SDK symbol, shown as secondary text.
    var apiName: String {
        switch self {
        case .profile: return "onNavigateToProfileCallback"
        case .profileEdit: return "onNavigateToProfileEditCallback"
        case .login: return "SSOConfiguration.loginRequired"
        case .clientObject: return "displayClientObjectCallback"
        case .groupAccessDenied: return "groupAccessDeniedCallback"
        }
    }

    func effectLine(wired: Bool) -> String {
        guard !wired else {
            switch self {
            case .profile: return "Tapping a member opens the app's own profile screen."
            case .profileEdit: return "Editing a field the app manages opens the app's profile editor."
            case .login: return "When sign-in is needed, the app's sign-in screen opens."
            case .clientObject: return "Tapping a post's content button reaches the app (a message confirms it)."
            case .groupAccessDenied: return "Opening a locked group lets the app answer with its own dialog."
            }
        }
        switch self {
        case .profile:
            return "Unified Profile needs this callback and the backend flag; without it, taps open the Octopus profile."
        case .profileEdit:
            return "Not handled by the app: the SDK hides \"Edit my profile\" in the Activity menu."
        case .groupAccessDenied:
            return "Not handled by the app: tapping a locked group does nothing."
        case .login, .clientObject:
            return "Not handled by the app: the SDK falls back to its own behaviour."
        }
    }
}

/// Why a row cannot be switched here, shown under its effect line.
enum HostCallbackLock: Equatable {
    /// The SDK cannot run without it, so it stays on whatever is stored.
    case required(String)
    /// Another control owns it; the row only mirrors it.
    case mirrored(String)

    var reason: String {
        switch self {
        case let .required(reason), let .mirrored(reason): return reason
        }
    }
}

/// Settings › Host app integration, minus the view: the callback rows with their count, the URL policy and
/// Restart now. Every input is injected so the rows are unit-tested without an SDK instance.
@MainActor
final class HostIntegrationViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let callback: HostCallback
        let isWired: Bool
        let lock: HostCallbackLock?

        var id: String { callback.id }
        var isSwitchable: Bool { lock == nil }
        var effect: String { callback.effectLine(wired: isWired) }
        var accessibilityId: String { "host-integration-\(callback.id)-switch" }
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var urlPolicy: HostURLPolicy

    var wiredCount: Int { rows.filter(\.isWired).count }
    var countLabel: String { "\(wiredCount)/\(rows.count)" }
    var countAccessibilityLabel: String { "\(wiredCount) of \(rows.count) on" }

    private let store: HostIntegrationStore
    private let isClientObjectWired: @MainActor () -> Bool
    private let restart: @MainActor () -> Void
    private var profileWired = false
    private var profileEditWired = true
    private var groupAccessDeniedWired = true
    private var storage = [AnyCancellable]()

    /// - Parameters:
    ///   - profileWired: whether `onNavigateToProfileCallback` is wired, owned by the Unified Profile switch.
    ///   - isClientObjectWired: read on `refresh()`; the SDK has no way to unset that callback, so it is mirrored.
    ///   - restart: closes the community and opens it again on its feed.
    init(store: HostIntegrationStore = .instance,
         profileWired: AnyPublisher<Bool, Never> = ClientProfileManager.instance.$isCallbackWired.eraseToAnyPublisher(),
         isClientObjectWired: @escaping @MainActor () -> Bool = HostIntegrationViewModel.liveClientObjectWired,
         restart: @escaping @MainActor () -> Void = { SampleTabRouter.instance.restartCommunity() }) {
        self.store = store
        self.isClientObjectWired = isClientObjectWired
        self.restart = restart
        urlPolicy = store.urlPolicy

        // `@Published` emits before the store's property changes, so the rows are built from the emitted values,
        // never by reading the store back.
        Publishers.CombineLatest3(profileWired, store.$isProfileEditWired, store.$isGroupAccessDeniedWired)
            .sink { [weak self] profile, profileEdit, groupAccessDenied in
                guard let self else { return }
                self.profileWired = profile
                profileEditWired = profileEdit
                groupAccessDeniedWired = groupAccessDenied
                refresh()
            }
            .store(in: &storage)
        store.$urlPolicy
            .sink { [weak self] in self?.urlPolicy = $0 }
            .store(in: &storage)
    }

    /// Rebuilds the rows from the current inputs, for example when the screen appears again.
    func refresh() {
        rows = Self.rows(profileWired: profileWired,
                         profileEditWired: profileEditWired,
                         clientObjectWired: isClientObjectWired(),
                         groupAccessDeniedWired: groupAccessDeniedWired)
    }

    /// Applies at once: the iOS SDK reads these callbacks when it needs them. Locked rows ignore the call.
    func set(_ callback: HostCallback, wired: Bool) {
        switch callback {
        case .profileEdit: store.setProfileEditWired(wired)
        case .groupAccessDenied: store.setGroupAccessDeniedWired(wired)
        case .profile, .login, .clientObject: break
        }
    }

    func select(_ policy: HostURLPolicy) {
        store.set(urlPolicy: policy)
    }

    func restartNow() {
        restart()
    }

    /// The rows in Android order, with what keeps a row from being switched on iOS.
    nonisolated static func rows(profileWired: Bool, profileEditWired: Bool, clientObjectWired: Bool,
                                 groupAccessDeniedWired: Bool) -> [Row] {
        HostCallback.allCases.map { callback in
            switch callback {
            case .profile:
                return Row(callback: callback, isWired: profileWired, lock: .mirrored(
                    "Follows Unified Profile in Configuration: one switch sets this callback and the backend flag."))
            case .profileEdit:
                return Row(callback: callback, isWired: profileEditWired, lock: nil)
            case .login:
                return Row(callback: callback, isWired: true, lock: .required(
                    "Required in SSO mode: the community does not open without it."))
            case .clientObject:
                return Row(callback: callback, isWired: clientObjectWired, lock: .mirrored(
                    "Wired by the Bridge to client object scenario; the iOS SDK cannot unset it."))
            case .groupAccessDenied:
                return Row(callback: callback, isWired: groupAccessDeniedWired, lock: nil)
            }
        }
    }

    /// Whether the live SDK carries a client object callback. Never builds the SDK: before it exists, nothing
    /// is wired.
    static func liveClientObjectWired() -> Bool {
        guard OctopusSDKProvider.isCreated else { return false }
        return OctopusSDKProvider.instance.octopus?.displayClientObjectCallback != nil
    }
}
