//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// The one screen that owns "who is signed in", the iOS twin of the Android sample's `AccountViewModel`.
///
/// The local record (`AppUserManager`) is what the *next* JWT will carry; the SDK session is what the backend
/// actually granted. The screen shows both and never pretends they are one value. The UI says "entitlements",
/// never "claim": the JWT is an implementation detail of the sample's token provider.
@MainActor
final class AccountViewModel: ObservableObject {
    /// What the screen needs from the app and the SDK, injected so the logic is unit-tested without either.
    struct Services {
        var appUser: AnyPublisher<AppUser?, Never>
        var session: AnyPublisher<SampleSession, Never>
        var connectOutcomes: AnyPublisher<ConnectOutcome, Never>
        /// The entitlements the local record holds when the screen opens.
        var storedEntitlements: () -> Set<Entitlement>
        /// Stores the user and entitlements, then calls `connectUser`; the result comes on `connectOutcomes`.
        var connect: (AppUser, Set<Entitlement>) -> Void
        /// Stores the entitlements, then asks the SDK to re-read them on the same session.
        var refreshEntitlements: (Set<Entitlement>) async throws -> Void
        /// Ends the Octopus session. The local record is kept: wiping it is what Reset configuration is for.
        var disconnect: () async throws -> Void
        /// The free-form entitlements the local record holds when the screen opens, beyond the known three.
        var storedCustomEntitlements: () -> Set<String> = { [] }
        /// Stores the free-form entitlements; called before a Connect or a Refresh, so the next token carries them.
        var storeCustomEntitlements: (Set<String>) -> Void = { _ in }
    }

    enum Message: Equatable {
        case info(String)
        case error(String)
    }

    /// The tester's fields: what the next Connect / Reconnect sends.
    @Published var userId = ""
    @Published var nickname = ""
    @Published private(set) var entitlements: Set<Entitlement>
    /// Entitlements typed on the Custom entitlement field, as Android's free-form set: anything the backend
    /// knows, `customer:vip` for instance.
    @Published private(set) var customEntitlements: Set<String>
    @Published private(set) var appUser: AppUser?
    @Published private(set) var session: SampleSession = .none
    @Published private(set) var isConnecting = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var message: Message?
    @Published var isEditProfilePresented = false

    private let services: Services
    private var storage = [AnyCancellable]()

    /// - Parameter services: `nil` for the app's own (`Services.live`); tests pass fakes.
    init(services: Services? = nil) {
        let services = services ?? .live
        self.services = services
        entitlements = services.storedEntitlements()
        customEntitlements = services.storedCustomEntitlements()

        services.appUser
            .sink { [weak self] user in
                guard let self else { return }
                appUser = user
                // The fields are edited locally: a store emission must not stomp on what the tester is typing.
                if userId.isEmpty { userId = user?.userId ?? "" }
                if nickname.isEmpty { nickname = user?.nickname ?? "" }
            }
            .store(in: &storage)
        services.session
            .sink { [weak self] in self?.session = $0 }
            .store(in: &storage)
        services.connectOutcomes
            .sink { [weak self] in self?.handle($0) }
            .store(in: &storage)
    }

    // MARK: - Derived state

    /// A real SSO identity, as opposed to the guest session the SDK opens on its own.
    var isSignedIn: Bool { session.isSignedIn }

    var statusLabel: String {
        guard session.hasProfile else { return "Off" }
        return session.isGuest ? "Guest" : "Connected"
    }

    var displayName: String {
        if let nickname = appUser?.nickname, !nickname.isEmpty { return nickname }
        return appUser?.userId ?? "No user"
    }

    var initials: String { Self.initials(nickname: appUser?.nickname, userId: appUser?.userId ?? "") }

    /// What the backend granted on the current session, `nil` while no user is signed in.
    var grantedEntitlements: Set<String>? { session.isSignedIn ? session.grantedEntitlements : nil }

    /// True when the local record asks for something the session does not carry: the one line that tells the
    /// tester why Reconnect is the button to press.
    var hasPendingEntitlementChange: Bool {
        Self.hasPendingChange(granted: grantedEntitlements, local: entitlements, custom: customEntitlements)
    }

    /// The custom chips, sorted as Android lists them.
    var sortedCustomEntitlements: [String] { customEntitlements.sorted() }

    func isGranted(_ entitlement: Entitlement) -> Bool {
        grantedEntitlements?.contains(entitlement.rawValue) ?? false
    }

    // MARK: - Actions

    func setEntitlement(_ entitlement: Entitlement, on: Bool) {
        if on { entitlements.insert(entitlement) } else { entitlements.remove(entitlement) }
        message = nil
    }

    /// The Custom entitlement field's Done: trimmed, empty ignored. A known value switches its row on instead of
    /// becoming a chip, so one entitlement never shows twice.
    func addCustomEntitlement(_ raw: String) {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let known = Entitlement(rawValue: value) {
            entitlements.insert(known)
        } else {
            customEntitlements.insert(value)
        }
        message = nil
    }

    func removeCustomEntitlement(_ value: String) {
        customEntitlements.remove(value)
        message = nil
    }

    /// Connect SSO User and Reconnect: forges a local JWT with these values and calls `connectUser`, the full
    /// path an added entitlement needs, as the backend only reads them when the token is minted.
    func connect() {
        let id = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            message = .error("User ID is required")
            return
        }
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = Self.user(id: id, nickname: trimmedNickname, keeping: appUser)
        message = nil
        isConnecting = true
        services.storeCustomEntitlements(customEntitlements)
        services.connect(user, entitlements)
    }

    /// The lighter path: same session, the SDK re-reads the entitlements.
    func refreshEntitlements() async {
        message = nil
        isRefreshing = true
        defer { isRefreshing = false }
        services.storeCustomEntitlements(customEntitlements)
        do {
            try await services.refreshEntitlements(entitlements)
            message = .info("Entitlements refreshed.")
        } catch {
            message = .error("Refresh failed: \(error)")
        }
    }

    func disconnect() async {
        message = nil
        do {
            try await services.disconnect()
            message = .info("Disconnected.")
        } catch {
            message = .error("Disconnect failed: \(error)")
        }
    }

    func dismissMessage() {
        message = nil
    }

    private func handle(_ outcome: ConnectOutcome) {
        // Only the calls this screen made: the app also connects on launch and after a community switch.
        guard isConnecting else { return }
        isConnecting = false
        if let failure = outcome.failure {
            message = .error("Connection failed: \(failure)")
        } else {
            message = .info("Connected as \(outcome.userId).")
        }
    }

    // MARK: - Pure helpers

    /// Initials for the avatar placeholder: at most two letters, never an emoji, "?" when there is nothing.
    nonisolated static func initials(nickname: String?, userId: String) -> String {
        let source = nickname.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? userId
        let letters = source
            .split(whereSeparator: { " -_.".contains($0) })
            .prefix(2)
            .compactMap(\.first)
            .map { String($0).uppercased() }
            .joined()
        return letters.isEmpty ? "?" : letters
    }

    nonisolated static func hasPendingChange(granted: Set<String>?, local: Set<Entitlement>,
                                             custom: Set<String> = []) -> Bool {
        guard let granted else { return false }
        return granted != Set(local.map(\.rawValue)).union(custom)
    }

    /// The user to connect: the typed id and nickname, keeping the bio and picture of the stored user when it
    /// is the same identity.
    nonisolated static func user(id: String, nickname: String, keeping stored: AppUser?) -> AppUser {
        let sameUser = stored?.userId == id
        return AppUser(userId: id,
                       nickname: nickname.isEmpty ? nil : nickname,
                       bio: sameUser ? stored?.bio : nil,
                       picture: sameUser ? stored?.picture : nil)
    }
}

extension AccountViewModel.Services {
    /// The app's `AppUserManager` and the live SDK. Never builds the SDK: before it exists, nothing is sent.
    @MainActor static var live: Self {
        let manager = AppUserManager.instance
        return Self(
            appUser: manager.$appUser.removeDuplicates().receive(on: DispatchQueue.main).eraseToAnyPublisher(),
            session: SampleSession.current(),
            // New outcomes only: the replayed one belongs to an earlier call.
            connectOutcomes: manager.$lastConnectOutcome.dropFirst().compactMap { $0 }
                .receive(on: DispatchQueue.main).eraseToAnyPublisher(),
            storedEntitlements: { manager.currentEntitlements },
            connect: { user, entitlements in
                manager.currentEntitlements = entitlements
                if manager.appUser == user {
                    manager.reconnect()
                } else {
                    manager.set(appUser: user)
                }
            },
            refreshEntitlements: { entitlements in
                manager.currentEntitlements = entitlements
                guard OctopusSDKProvider.isCreated, let octopus = OctopusSDKProvider.instance.octopus else { return }
                try await octopus.refreshEntitlements()
            },
            disconnect: { try await manager.disconnect() },
            storedCustomEntitlements: { manager.currentCustomEntitlements },
            storeCustomEntitlements: { manager.currentCustomEntitlements = $0 })
    }
}
