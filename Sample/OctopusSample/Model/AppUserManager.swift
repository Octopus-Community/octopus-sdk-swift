//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// This class mimicks the way the real app is managing the connected user.
/// As soon as it has a user or its profile changes, it calls `octopus.connectUser` or `octopus.disconnectUser`
class AppUserManager: ObservableObject {
    static let instance = AppUserManager()

    @Published var appUser: AppUser?
    @Published var connectionError: OctopusConnectUserError?
    /// The outcome of the last `connectUser` the sample made, for the Account screen's message line.
    @Published private(set) var lastConnectOutcome: ConnectOutcome?

    /// Test-harness entitlements that get embedded in the next client-signed JWT minted by
    /// `TokenProvider`. In a real client app these are sourced from the backend session;
    /// here we let the tester edit them directly from Settings › Account.
    ///
    /// Persisted, like the Android sample's user record: after a relaunch the next token still asks for the set
    /// the session was granted. Settings › Reset configuration clears it.
    var currentEntitlements: Set<Entitlement> {
        get { Entitlement.decode(UserDefaults.standard.stringArray(forKey: Self.entitlementsKey)) }
        set { UserDefaults.standard.set(Entitlement.encode(newValue), forKey: Self.entitlementsKey) }
    }

    static let entitlementsKey = "OctopusSample.account.entitlements"

    /// The free-form entitlements typed on Settings › Account › Custom entitlement, beyond the known three.
    /// Persisted and cleared with `currentEntitlements`.
    var currentCustomEntitlements: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.customEntitlementsKey) ?? []) }
        set { UserDefaults.standard.set(newValue.sorted(), forKey: Self.customEntitlementsKey) }
    }

    static let customEntitlementsKey = "OctopusSample.account.customEntitlements"

    /// What the next token asks for: the known entitlements and the custom ones, deduplicated and sorted.
    static func tokenEntitlements(known: Set<Entitlement>, custom: Set<String>) -> [String] {
        Set(known.map(\.rawValue)).union(custom).sorted()
    }

    private let appUserStore = AppUserStore()
    private let tokenProvider = TokenProvider()
    private var storage = [AnyCancellable]()
    private var userChangedInApp = false

    private init() {
        Publishers.CombineLatest(
            appUserStore.$user.removeDuplicates(),
            NotificationCenter.default.publisher(for: .apiKeyChanged).prepend(Notification(name: .apiKeyChanged))
        ).sink { [unowned self] appUser, _ in
            self.appUser = appUser
            let displayErrors = userChangedInApp
            userChangedInApp = false

            guard let octopus = OctopusSDKProvider.instance.octopus else { return }

            if let appUser = Self.userToConnect(appUser, isSignedOut: appUserStore.isSignedOut) {
                connect(appUser, on: octopus, displayErrors: displayErrors)
            } else {
                Task {
                    do {
                        try await octopus.disconnectUser()
                    } catch {
                        print("Error while disconnecting user: \(error)")
                    }
                }
            }
        }.store(in: &storage)
    }

    func set(appUser: AppUser?) {
        userChangedInApp = true
        appUserStore.set(user: appUser)
    }

    /// Calls `connectUser` again for the current user, with `currentEntitlements`: what an entitlement change
    /// needs, as the backend reads them when the token is minted. `set(appUser:)` only connects on a change.
    /// It also signs back in a user who disconnected.
    ///
    /// The iOS SDK does not ask for a new token when the same user is already connected, so the call is followed
    /// by `refreshEntitlements()`: without it, the session would keep the previous set.
    func reconnect() {
        guard let appUser, let octopus = OctopusSDKProvider.instance.octopus else { return }
        appUserStore.setSignedOut(false)
        connect(appUser, on: octopus, displayErrors: false, refreshingEntitlements: true)
    }

    /// Signs the user out of the community but keeps them as the app's user, so Connect can sign them back in.
    /// The sign-out is remembered: without it, the next launch would connect the stored user again.
    func disconnect() async throws {
        if OctopusSDKProvider.isCreated, let octopus = OctopusSDKProvider.instance.octopus {
            try await octopus.disconnectUser()
        }
        appUserStore.setSignedOut(true)
    }

    /// The user to connect on launch or after a community switch: the stored one, unless they signed out.
    static func userToConnect(_ stored: AppUser?, isSignedOut: Bool) -> AppUser? {
        isSignedOut ? nil : stored
    }

    private func connect(_ appUser: AppUser, on octopus: OctopusSDK, displayErrors: Bool,
                         refreshingEntitlements: Bool = false) {
        let clientUser = ClientUser(
            userId: appUser.userId,
            profile: .init(nickname: appUser.nickname, bio: appUser.bio,
                           picture: appUser.picture))
        Task { [weak self] in
            guard let self else { return }
            do {
                try await octopus.connectUser(
                    clientUser,
                    tokenProvider: { [weak self] in
                        guard let self else { throw NSError(domain: "", code: 0, userInfo: nil) }
                        return try await self.tokenProvider.getClientUserToken(
                            userId: appUser.userId,
                            entitlements: Self.tokenEntitlements(known: self.currentEntitlements,
                                                         custom: self.currentCustomEntitlements)
                        )
                    })
                if refreshingEntitlements {
                    try await octopus.refreshEntitlements()
                }
                await MainActor.run {
                    self.connectionError = nil
                    self.lastConnectOutcome = ConnectOutcome(userId: appUser.userId, failure: nil)
                }
            } catch {
                print("Error while connecting user: \(error)")
                await MainActor.run {
                    self.lastConnectOutcome = ConnectOutcome(userId: appUser.userId,
                                                             failure: String(describing: error))
                    if let error = error as? OctopusConnectUserError, displayErrors { self.connectionError = error }
                }
            }
        }
    }
}

/// One `connectUser` call and how it ended. A new value for every call, so two identical outcomes in a row are
/// still two events.
struct ConnectOutcome: Equatable {
    let id = UUID()
    let userId: String
    /// Why the call failed, `nil` when it succeeded.
    let failure: String?
}
