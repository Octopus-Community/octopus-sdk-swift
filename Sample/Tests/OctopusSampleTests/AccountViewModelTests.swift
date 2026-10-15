//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import XCTest
@testable import OctopusSample

/// Settings › Account: the fields seeded from the stored user, Connect / Reconnect and its message, the
/// pending-entitlements line, Refresh and Disconnect, all against fake services.
@MainActor
final class AccountViewModelTests: XCTestCase {
    private struct Failure: Error, CustomStringConvertible {
        var description: String { "offline" }
    }

    private var appUser: CurrentValueSubject<AppUser?, Never>!
    private var session: CurrentValueSubject<SampleSession, Never>!
    private var outcomes: PassthroughSubject<ConnectOutcome, Never>!
    private var connected: [(AppUser, Set<Entitlement>)] = []
    private var refreshed: [Set<Entitlement>] = []
    private var disconnects = 0
    private var refreshError: Error?

    override func setUp() {
        super.setUp()
        appUser = CurrentValueSubject(nil)
        session = CurrentValueSubject(.none)
        outcomes = PassthroughSubject()
        connected = []
        refreshed = []
        disconnects = 0
        refreshError = nil
    }

    private func makeViewModel(stored: Set<Entitlement> = []) -> AccountViewModel {
        AccountViewModel(services: .init(
            appUser: appUser.eraseToAnyPublisher(),
            session: session.eraseToAnyPublisher(),
            connectOutcomes: outcomes.eraseToAnyPublisher(),
            storedEntitlements: { stored },
            connect: { [unowned self] in connected.append(($0, $1)) },
            refreshEntitlements: { [unowned self] in
                refreshed.append($0)
                if let refreshError { throw refreshError }
            },
            disconnect: { [unowned self] in disconnects += 1 }))
    }

    private func signIn(granted: Set<String>) {
        session.send(SampleSession(hasProfile: true, isGuest: false, grantedEntitlements: granted))
    }

    // MARK: - Fields and identity

    func testFieldsAreSeededFromTheStoredUserButNeverOverwriteTyping() {
        appUser.send(AppUser(userId: "user-1", nickname: "Ada"))
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.userId, "user-1")
        XCTAssertEqual(viewModel.nickname, "Ada")

        viewModel.userId = "user-2"
        appUser.send(AppUser(userId: "user-3", nickname: "Bea"))
        XCTAssertEqual(viewModel.userId, "user-2")
    }

    func testStatusAndIdentity() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.statusLabel, "Off")
        XCTAssertEqual(viewModel.displayName, "No user")
        XCTAssertEqual(viewModel.initials, "?")

        session.send(SampleSession(hasProfile: true, isGuest: true, grantedEntitlements: []))
        XCTAssertEqual(viewModel.statusLabel, "Guest")
        XCTAssertFalse(viewModel.isSignedIn)

        appUser.send(AppUser(userId: "user-1", nickname: "Ada Lovelace"))
        signIn(granted: [])
        XCTAssertEqual(viewModel.statusLabel, "Connected")
        XCTAssertEqual(viewModel.displayName, "Ada Lovelace")
        XCTAssertEqual(viewModel.initials, "AL")
    }

    func testInitialsTakeAtMostTwoWordsAndFallBackToTheUserId() {
        XCTAssertEqual(AccountViewModel.initials(nickname: "ada-byron_lovelace", userId: "x"), "AB")
        XCTAssertEqual(AccountViewModel.initials(nickname: " ", userId: "qa.tester"), "QT")
        XCTAssertEqual(AccountViewModel.initials(nickname: nil, userId: ""), "?")
    }

    // MARK: - Connect

    func testConnectRequiresAUserId() {
        let viewModel = makeViewModel()
        viewModel.userId = "   "
        viewModel.connect()
        XCTAssertEqual(viewModel.message, .error("User ID is required"))
        XCTAssertTrue(connected.isEmpty)
    }

    func testConnectSendsTheFieldsAndTheEntitlementsThenReportsTheOutcome() {
        let viewModel = makeViewModel(stored: [.premium])
        viewModel.userId = " user-1 "
        viewModel.nickname = ""
        viewModel.setEntitlement(.moderator, on: true)
        viewModel.connect()

        XCTAssertTrue(viewModel.isConnecting)
        XCTAssertEqual(connected.first?.0, AppUser(userId: "user-1"))
        XCTAssertEqual(connected.first?.1, [.premium, .moderator])

        outcomes.send(ConnectOutcome(userId: "user-1", failure: nil))
        XCTAssertFalse(viewModel.isConnecting)
        XCTAssertEqual(viewModel.message, .info("Connected as user-1."))
    }

    func testAFailedConnectIsReported() {
        let viewModel = makeViewModel()
        viewModel.userId = "user-1"
        viewModel.connect()
        outcomes.send(ConnectOutcome(userId: "user-1", failure: "offline"))
        XCTAssertEqual(viewModel.message, .error("Connection failed: offline"))
    }

    func testAnOutcomeTheScreenDidNotAskForIsIgnored() {
        let viewModel = makeViewModel()
        outcomes.send(ConnectOutcome(userId: "user-1", failure: nil))
        XCTAssertNil(viewModel.message)
    }

    func testReconnectingTheSameUserKeepsItsBioAndPicture() {
        let stored = AppUser(userId: "user-1", nickname: "Ada", bio: "Bio", picture: Data([1]))
        XCTAssertEqual(AccountViewModel.user(id: "user-1", nickname: "Ada L", keeping: stored),
                       AppUser(userId: "user-1", nickname: "Ada L", bio: "Bio", picture: Data([1])))
        XCTAssertEqual(AccountViewModel.user(id: "user-2", nickname: "", keeping: stored),
                       AppUser(userId: "user-2"))
    }

    // MARK: - Entitlements

    func testPendingWhenTheLocalSetDiffersFromTheGrantedOne() {
        let viewModel = makeViewModel(stored: [.premium])
        XCTAssertFalse(viewModel.hasPendingEntitlementChange, "Nothing is pending without a signed-in session")

        signIn(granted: ["customer:premium"])
        XCTAssertFalse(viewModel.hasPendingEntitlementChange)
        XCTAssertTrue(viewModel.isGranted(.premium))
        XCTAssertFalse(viewModel.isGranted(.moderator))

        viewModel.setEntitlement(.moderator, on: true)
        XCTAssertTrue(viewModel.hasPendingEntitlementChange)

        viewModel.setEntitlement(.moderator, on: false)
        XCTAssertFalse(viewModel.hasPendingEntitlementChange)
    }

    func testRefreshSendsTheLocalSetAndReportsTheResult() async {
        let viewModel = makeViewModel(stored: [.verified])
        await viewModel.refreshEntitlements()
        XCTAssertEqual(refreshed, [[.verified]])
        XCTAssertEqual(viewModel.message, .info("Entitlements refreshed."))
        XCTAssertFalse(viewModel.isRefreshing)

        refreshError = Failure()
        await viewModel.refreshEntitlements()
        XCTAssertEqual(viewModel.message, .error("Refresh failed: offline"))
    }

    func testDisconnectEndsTheSessionOnly() async {
        appUser.send(AppUser(userId: "user-1"))
        let viewModel = makeViewModel()
        await viewModel.disconnect()
        XCTAssertEqual(disconnects, 1)
        XCTAssertEqual(viewModel.message, .info("Disconnected."))
        XCTAssertEqual(viewModel.userId, "user-1")
        XCTAssertTrue(connected.isEmpty)
    }

    // MARK: - Custom entitlements

    func testCustomEntitlementsAreTrimmedSortedStoredAndKnownValuesSwitchTheirRow() {
        var stored: Set<String> = ["zeta"]
        var services = AccountViewModel.Services(
            appUser: appUser.eraseToAnyPublisher(),
            session: session.eraseToAnyPublisher(),
            connectOutcomes: outcomes.eraseToAnyPublisher(),
            storedEntitlements: { [] },
            connect: { [unowned self] in connected.append(($0, $1)) },
            refreshEntitlements: { _ in },
            disconnect: {})
        services.storedCustomEntitlements = { stored }
        services.storeCustomEntitlements = { stored = $0 }
        let viewModel = AccountViewModel(services: services)
        XCTAssertEqual(viewModel.sortedCustomEntitlements, ["zeta"])

        viewModel.addCustomEntitlement("  customer:vip ")
        viewModel.addCustomEntitlement("   ")
        viewModel.addCustomEntitlement(Entitlement.premium.rawValue)
        XCTAssertEqual(viewModel.sortedCustomEntitlements, ["customer:vip", "zeta"])
        XCTAssertTrue(viewModel.entitlements.contains(.premium), "A known value switches its row on")

        viewModel.removeCustomEntitlement("zeta")
        XCTAssertEqual(stored, ["zeta"], "Nothing is stored before Connect")
        viewModel.userId = "user-1"
        viewModel.connect()
        XCTAssertEqual(stored, ["customer:vip"])
    }

    func testCustomEntitlementsCountInThePendingChangeAndTheToken() {
        XCTAssertFalse(AccountViewModel.hasPendingChange(granted: ["customer:premium", "customer:vip"],
                                                         local: [.premium], custom: ["customer:vip"]))
        XCTAssertTrue(AccountViewModel.hasPendingChange(granted: ["customer:premium"],
                                                        local: [.premium], custom: ["customer:vip"]))
        XCTAssertEqual(
            AppUserManager.tokenEntitlements(known: [.verified, .premium], custom: ["a:b", "customer:premium"]),
            ["a:b", "customer:premium", "customer:verified"])
    }
}
