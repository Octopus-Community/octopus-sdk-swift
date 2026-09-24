//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// View model of CommunityDataView.
///
/// Drives the whole Unified Profile read surface (OCT-1374): the two `fetchCommunityData` overloads
/// and the two `communityDataPublisher` overloads, plus the observation lifecycle the QA presets make
/// visible.
///
/// - Note: the catalog's `flow error` live-state row has no iOS counterpart on purpose.
///   ``OctopusSDK/communityDataPublisher(clientUserId:)`` is an `AnyPublisher<_, Never>`: a failed
///   client-user-id resolution emits `nil` rather than an error, so the row could never be rendered.
///   It was already conditional on Flutter, hence absent in normal operation there too.
@MainActor
class CommunityDataViewModel: ObservableObject {
    enum Preset: Int, CaseIterable, Identifiable {
        case fetchByClientUserId = 1
        case fetchByProfileId = 2
        case observeByClientUserId = 3
        case stopObserving = 4
        case idContract = 5
        case openClientProfile = 6

        var id: Int { rawValue }

        // Labels are the cross-platform contract from the pm-tools scenario catalog, applied verbatim
        // so the QA pipeline drives Android, iOS and Flutter with the same strings.
        var label: String {
            switch self {
            case .fetchByClientUserId: "Preset 1 · Fetch by clientUserId"
            case .fetchByProfileId: "Preset 2 · Fetch by profileId (from the last lookup)"
            case .observeByClientUserId: "Preset 3 · Observe by clientUserId (start)"
            case .stopObserving: "Preset 4 · Stop observing"
            case .idContract: "Preset 5 · Contract: both / neither id throws"
            case .openClientProfile: "Preset 6 · Open the host-rendered profile page"
            }
        }

        var testId: String { "qa-preset-communityData-\(rawValue)" }

        /// Whether running this preset performs an async fetch — the only two that `run(_:)` gates on
        /// `isLoading`, and therefore the only two the view disables while one is in flight.
        var isAsync: Bool {
            switch self {
            case .fetchByClientUserId, .fetchByProfileId: true
            case .observeByClientUserId, .stopObserving, .idContract, .openClientProfile: false
            }
        }
    }

    /// Latest value seen from either a fetch or the observation.
    @Published private(set) var data: OctopusCommunityData?

    /// Where ``data`` came from — makes it obvious in QA whether the value on screen was pushed by
    /// the observation or pulled by a fetch.
    @Published private(set) var source = "—"

    /// The Octopus profile id learned from a successful lookup, so the `profileId` preset needs no
    /// hand-typed id.
    @Published private(set) var lastProfileId: String?

    @Published private(set) var isObserving = false

    /// The `clientUserId` the SDK reports for the connected user, surfaced as its own live-state row.
    @Published private(set) var profileClientUserId: String?

    /// The host-side id to look the member up by: the id the SDK reports for the connected user when
    /// available, else the id the host itself signed in with.
    ///
    /// Unlike Flutter — where the example always holds an SSO subject — this is optional here: in
    /// `.octopus` (magic link) mode the host has no client user id at all, and the presets say so
    /// instead of looking up an empty string.
    ///
    /// Republished rather than computed, so the live-state row refreshes on an `AppUserManager` change
    /// too — it is not an `ObservableObject` this view could observe on its own.
    @Published private(set) var lookupClientUserId: String?

    /// Result of the last preset — the panel the QA pipeline reads.
    @Published private(set) var result: String?
    @Published private(set) var isError = false

    /// Set while an async preset is in flight, so the result panel never shows the *previous* preset's
    /// outcome as if it were the current one (mirrors the Android section's `loading…`).
    @Published private(set) var isLoading = false

    /// Set by preset 6, consumed by the view to present the host-rendered profile screen.
    @Published var clientProfileTarget: ClientProfileTarget?

    /// Identifiable wrapper so preset 6 can drive `fullScreenCover(item:)` — presenting on an optional
    /// item avoids the blank-body window a `Bool` binding derived from the same optional would open.
    struct ClientProfileTarget: Identifiable {
        let id: String
    }

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus
    private var observation: AnyCancellable?
    private var storage = [AnyCancellable]()

    init() {
        // One subscription feeds both id rows. `sink [weak self]` rather than `assign(to:on:)`: the
        // latter retains its target strongly, so storing the cancellable on `self` would make the
        // view model immortal — and would also cost us the deallocation that releases `observation`.
        Publishers.CombineLatest(
            octopus.$profile.map { $0?.clientUserId },
            AppUserManager.instance.$appUser.map { $0?.userId }
        )
        .removeDuplicates { $0 == $1 }
        // Both upstreams happen to emit on main today, but neither guarantees it by construction and
        // the sample builds in Swift 5 mode — nothing would diagnose a regression. Keep the invariant
        // local rather than relying on an audit of every assignment site.
        .receive(on: DispatchQueue.main)
        .sink { [weak self] profileClientUserId, appUserId in
            self?.profileClientUserId = profileClientUserId
            self?.lookupClientUserId = profileClientUserId ?? appUserId
        }
        .store(in: &storage)
    }

    func run(_ preset: Preset) {
        switch preset {
        // The two async presets flip `isLoading` here, synchronously with the tap, so the guard is a
        // real mutual exclusion rather than a check racing the flag it protects. Only these two are
        // gated: blocking the synchronous presets would leave "Stop observing" — the lifecycle this
        // scenario exists to demonstrate — inert for the whole duration of a slow fetch.
        case .fetchByClientUserId:
            guard !isLoading else { return }
            isLoading = true
            Task { await fetchByClientUserId() }
        case .fetchByProfileId:
            guard !isLoading else { return }
            isLoading = true
            Task { await fetchByProfileId() }
        case .observeByClientUserId: observeByClientUserId()
        case .stopObserving: stopObservingPreset()
        case .idContract: reportIdContract()
        case .openClientProfile: openClientProfile()
        }
    }

    /// Cancels the observation. Dropping the cancellable tears the SDK subscription down, so the
    /// observation lifecycle is genuinely observable from preset 3 / preset 4.
    func stopObserving() {
        observation = nil
        isObserving = false
    }

    // MARK: - Presets

    private func fetchByClientUserId() async {
        // First statement, so every exit clears the flag `run(_:)` set — including the guard below.
        defer { isLoading = false }
        guard let clientUserId = lookupClientUserId else {
            setResult(Self.noClientUserIdMessage, isError: true)
            return
        }
        clearPreviousResult()
        do {
            let data = try await octopus.fetchCommunityData(clientUserId: clientUserId)
            record(data, source: "fetch(clientUserId)")
            setResult(
                data == nil
                    ? "Unknown member for clientUserId \"\(clientUserId)\" (nil — the community may " +
                      "not expose client user ids)."
                    : "Fetched: \(Self.describe(data))"
            )
        } catch {
            setResult("fetchCommunityData failed: \(error)", isError: true)
        }
    }

    private func fetchByProfileId() async {
        defer { isLoading = false }
        guard let profileId = lastProfileId else {
            setResult("No profileId known yet — run Preset 1 or 3 first.", isError: true)
            return
        }
        clearPreviousResult()
        do {
            let data = try await octopus.fetchCommunityData(profileId: profileId)
            record(data, source: "fetch(profileId)")
            setResult(
                data == nil
                    ? "Unknown member for profileId \"\(profileId)\"."
                    : "Fetched: \(Self.describe(data))"
            )
        } catch {
            setResult("fetchCommunityData failed: \(error)", isError: true)
        }
    }

    private func observeByClientUserId() {
        guard let clientUserId = lookupClientUserId else {
            setResult(Self.noClientUserIdMessage, isError: true)
            return
        }
        stopObserving()
        observation = octopus.communityDataPublisher(clientUserId: clientUserId)
            .sink { [weak self] data in
                self?.record(data, source: "publisher(clientUserId)")
            }
        isObserving = true
        setResult(
            "Observing community data for clientUserId \"\(clientUserId)\". Run Preset 1 or act in " +
            "the community to see an emission."
        )
    }

    private func stopObservingPreset() {
        let wasObserving = isObserving
        stopObserving()
        setResult(
            wasObserving
                ? "Cancelled the subscription — the SDK observation is torn down."
                : "Nothing was being observed."
        )
    }

    /// Preset 5 has no runtime counterpart on iOS, and reports exactly that.
    ///
    /// Flutter folds the four methods into two, with optional named parameters, so it can enforce
    /// "exactly one id" at runtime with an `ArgumentError`. iOS — like Android — exposes four distinct
    /// methods, so passing both ids or neither simply does not compile: the contract holds a stronger
    /// guarantee than the one the catalog describes. The button is still rendered with the contract's
    /// verbatim test id, because an absent element reads as a failure to the QA Tester while iOS is
    /// listed in the scenario's `platforms`.
    private func reportIdContract() {
        setResult(
            "Compile-time guarantee on iOS: fetchCommunityData / communityDataPublisher each expose " +
            "two distinct overloads (clientUserId: or profileId:), so passing both ids or neither " +
            "does not compile. Nothing to assert at runtime — no ArgumentError equivalent exists."
        )
    }

    private func openClientProfile() {
        guard let clientUserId = lookupClientUserId else {
            setResult(Self.noClientUserIdMessage, isError: true)
            return
        }
        clientProfileTarget = ClientProfileTarget(id: clientUserId)
        setResult(
            "Presented the host profile screen for \"\(clientUserId)\" — it fetches and renders the " +
            "community data in the host's own UI."
        )
    }

    // MARK: - Private

    private static let noClientUserIdMessage =
        "No clientUserId available — connect a user in SSO mode (the Octopus magic-link mode has no " +
        "host-side id to look up)."

    /// Clears the previous outcome before an async preset runs, so the panel the QA pipeline reads can
    /// never be mistaken for the current preset's result while the fetch is still in flight.
    /// `isLoading` is owned by `run(_:)` — see the comment there.
    private func clearPreviousResult() {
        result = nil
        isError = false
    }

    private func record(_ data: OctopusCommunityData?, source: String) {
        self.data = data
        self.source = source
        if let data { lastProfileId = data.profileId }
    }

    private func setResult(_ result: String, isError: Bool = false) {
        self.result = result
        self.isError = isError
    }

    private static func describe(_ data: OctopusCommunityData?) -> String {
        guard let data else { return "nil" }
        let level = data.gamification.map { String($0.level) } ?? "null"
        let score = data.gamification?.score.map(String.init) ?? "null"
        return "profileId: \(data.profileId), messageCount: \(data.messageCount.map(String.init) ?? "null"), " +
               "gamification.level: \(level), gamification.score: \(score)"
    }
}
