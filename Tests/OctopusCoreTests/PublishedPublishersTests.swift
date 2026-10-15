//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// Every OctopusCore object with `@Published` values must leave its `init` with all their publishers created (see
/// `PublishedPublishers`), so that no later first `$value` access can race a write from another thread. Two kinds are
/// left out: `Feed`, isolated to the main actor, where every write and `$value` access already happens; and the test
/// doubles in `Mocks`, written from the test's own thread.
///
/// What this checks is the state when `init` returns, not that the publishers were created before the first sink or
/// task that can write them: a value `init` reads through `$value` itself passes either way, and so would a
/// `PublishedPublishers` call moved to the end of `init`. Where the call sits is left to review.
///
/// Whether a publisher exists is read with `Mirror` on the `@Published` storage, which is not a documented API:
/// `publishedStorageIsReadable` pins what these tests rely on, and fails first if Combine ever lays it out otherwise.
@Suite(.serialized)
struct PublishedPublishersTests {

    /// The objects that call `PublishedPublishers` in their `init`.
    enum Subject: String, CaseIterable, CustomTestStringConvertible {
        case appStateMonitor, blockedUserIdsProvider, clientUserProvider, configRepository, connectionRepository
        case contentTranslationPreferenceRepository, languageRepository, notificationsRepository, profileRepository
        case sessionManager, sessionStore, toastsRepository, topicsRepository, trackingEventsSendingMonitor
        case userDataStorage, userProfileFetchMonitor

        var testDescription: String { rawValue }

        /// A new instance, built right before it is inspected so that nothing else accessed its values.
        func make(injector: Injector, userDefaults: UserDefaults) -> AnyObject {
            switch self {
            case .appStateMonitor: AppStateMonitorDefault()
            case .blockedUserIdsProvider: BlockedUserIdsProviderDefault(injector: injector)
            case .clientUserProvider: ClientUserProvider(injector: injector)
            case .configRepository: ConfigRepositoryDefault(injector: injector)
            case .connectionRepository:
                SSOConnectionRepository(
                    connectionMode: .sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in })),
                    injector: injector)
            case .contentTranslationPreferenceRepository:
                ContentTranslationPreferenceRepositoryDefault(injector: injector)
            case .languageRepository: LanguageRepository(injector: injector)
            case .notificationsRepository: NotificationsRepository(injector: injector)
            case .profileRepository: ProfileRepositoryDefault(appManagedFields: [], injector: injector)
            case .sessionManager: SessionManager(kind: .app, userDefaults: userDefaults)
            case .sessionStore: SessionStore(prefix: "publishedPublishersTests", userDefaults: userDefaults)
            case .toastsRepository: ToastsRepository(injector: injector)
            case .topicsRepository: TopicsRepository(injector: injector)
            case .trackingEventsSendingMonitor: TrackingEventsSendingMonitor(injector: injector)
            case .userDataStorage: UserDataStorage(injector: injector)
            case .userProfileFetchMonitor: UserProfileFetchMonitorDefault(injector: injector)
            }
        }
    }

    @Test func publishedStorageIsReadable() throws {
        let object = PublishedHolder()
        #expect(try #require(unpublishedProperties(of: object)) == ["_value"])
        _ = object.$value
        #expect(try #require(unpublishedProperties(of: object)) == [])
    }

    // On the main actor, so that building the object and inspecting it happen in one go: nothing its `init`
    // schedules on the main queue (where several of them first read a `$value` in a sink) can run in between.
    @MainActor
    @Test(arguments: Subject.allCases)
    func publishersAreCreatedByInit(_ subject: Subject) throws {
        let suiteName = "PublishedPublishersTests.\(subject.rawValue)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let object = subject.make(injector: makeInjector(), userDefaults: userDefaults)

        #expect(try #require(unpublishedProperties(of: object)) == [])
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .userProfileFetchMonitor,
                               .blockedUserIdsProvider, .appStateMonitor)
        // Offline, so that no object starts a network refresh: each one is released right after being inspected,
        // and a refresh task still running at that point would outlive it.
        (injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor).connectionAvailable = false
        injector.register { _ in MockUserNotificationCenterProvider() }
        injector.register { UserDataStorage(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        injector.register { ProfileRepositoryDefault(appManagedFields: [], injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { TopicsDatabase(injector: $0) }
        injector.register { ClientUserProvider(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { ConfigRepositoryDefault(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.register { EventsDatabase(injector: $0) }
        injector.register { NotificationsDatabase(injector: $0) }
        injector.register { NotificationSettingsDatabase(injector: $0) }
        return injector
    }
}

/// The names of the `@Published` properties of `object` whose publisher is not created yet, or `nil` when the
/// `@Published` storage is not laid out as these tests expect (a `storage` enum with `value` and `publisher` cases).
private func unpublishedProperties(of object: AnyObject) -> [String]? {
    var names = [String]()
    var foundPublished = false
    var mirror: Mirror? = Mirror(reflecting: object)
    while let current = mirror {
        for child in current.children where String(describing: type(of: child.value)).hasPrefix("Published<") {
            foundPublished = true
            guard let storage = Mirror(reflecting: child.value).children.first(where: { $0.label == "storage" }),
                  let storageCase = Mirror(reflecting: storage.value).children.first?.label else { return nil }
            switch storageCase {
            case "value": names.append(child.label ?? "?")
            case "publisher": break
            default: return nil
            }
        }
        mirror = current.superclassMirror
    }
    return foundPublished ? names : nil
}

private final class PublishedHolder {
    @Published var value = 0
}
