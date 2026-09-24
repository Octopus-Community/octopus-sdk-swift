//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels
import Combine
import OctopusDependencyInjection
import os

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDKCore: ObservableObject {
    public let connectionRepository: ConnectionRepository
    public let profileRepository: ProfileRepository
    public let rootFeedsRepository: RootFeedsRepository
    public let postsRepository: PostsRepository
    public let commentsRepository: CommentsRepository
    public let repliesRepository: RepliesRepository
    public let userCommentsRepository: UserCommentsRepository
    public let topicsRepository: TopicsRepository
    public let moderationRepository: ModerationRepository
    public let reactionsRepository: ReactionsRepository
    public let externalLinksRepository: ExternalLinksRepository
    public let trackingRepository: TrackingRepository
    public let notificationsRepository: NotificationsRepository
    public let configRepository: ConfigRepository
    public let contentTranslationPreferenceRepository: ContentTranslationPreferenceRepository
    public let toastsRepository: ToastsRepository
    public let videosRepository: VideosRepository
    public let sdkEventsEmitter: SdkEventsEmitter
    public let languageRepository: LanguageRepository
    public let octopusDrivenLoginMonitor: OctopusDrivenLoginMonitor

    public let validators: Validators

    public let sdkConfig: OctopusSDKConfiguration

    /// Whether the device currently has a network connection. The UI keeps its "no connection" toast up
    /// until this turns back to `true` (Screen states spec).
    public var connectionAvailablePublisher: AnyPublisher<Bool, Never> {
        injector.getInjected(identifiedBy: Injected.networkMonitor).connectionAvailablePublisher
    }

    /// See `OctopusSDK.debugOverrideConnectionAvailable(_:)`.
    ///
    /// Not behind `#if DEBUG`, unlike an earlier revision: the public wrapper is gated by
    /// `@_spi(OctopusInternalTesting)` — like the five other `debugOverride*` affordances — and the
    /// Sample calls it unguarded. A DEBUG-only member broke the Release archive of the internal
    /// TestFlight build, which is precisely the build that needs it: a simulator always reports a
    /// connection, so only a real device can exercise the offline states.
    public func debugOverrideConnectionAvailable(_ available: Bool?) {
        injector.getInjected(identifiedBy: Injected.networkMonitor)
            .debugOverrideConnectionAvailable(available)
    }

    private let injector: Injector
    private let connectionMode: ConnectionMode

    /// Constructor
    /// - Parameter apiKey: the API key that identifies your project
    public init(apiKey: String, connectionMode: ConnectionMode, sdkConfig: OctopusSDKConfiguration,
                cleanAfterCommunitySwitch: Bool = false,
                injector: Injector) throws {
        self.connectionMode = connectionMode
        self.sdkConfig = sdkConfig
        self.injector = injector
        let installIdProvider = InstallIdProvider()
        let modelCoreDataStack = try ModelCoreDataStack(forceReset: cleanAfterCommunitySwitch)
        let trackingCoreDataStack = try TrackingCoreDataStack(forceReset: cleanAfterCommunitySwitch)
        let configCoreDataStack = try ConfigCoreDataStack(forceReset: cleanAfterCommunitySwitch)
        injector.register { LanguageRepository(injector: $0) }
        injector.register { _ in SecuredStorageDefault(apiKey: apiKey, isNewInstall: installIdProvider.isNewInstall) }
        injector.register { UserDataStorage(injector: $0) }
        languageRepository = injector.getInjected(identifiedBy: Injected.languageRepository)
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let remoteClient = try GrpcClient(
            apiKey: apiKey, sdkVersion: version, installId: installIdProvider.installId,
            localeIdentifier: languageRepository.localeIdentifier,
            serverHost: sdkConfig.apiServer?.host,
            serverPort: sdkConfig.apiServer?.port,
            getUserIdBlock: { [userDataStorage] in
                userDataStorage.userData?.id
            },
            updateTokenBlock: { [userDataStorage] newToken in
                guard let userData = userDataStorage.userData else { return }
                let newUserData = UserDataStorage.UserData(id: userData.id, clientId: userData.clientId, jwtToken: newToken)
                userDataStorage.store(userData: newUserData)
            })
        injector.register { _ in remoteClient }
        injector.register { _ in modelCoreDataStack }
        injector.register { _ in configCoreDataStack }
        injector.register { _ in NetworkMonitorDefault() }
        injector.register { _ in AppStateMonitorDefault() }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { UserProfileFetchMonitorDefault(injector: $0) }
        injector.register { EntitlementMonitor(injector: $0) }
        injector.register { PostChildChangeMonitor(injector: $0) }
        injector.register { LanguageChangedMonitor(injector: $0) }
        injector.register { BlockedUserIdsProviderDefault(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        // Repository
        injector.register { ConfigRepositoryDefault(injector: $0, forceReset: cleanAfterCommunitySwitch) }
        injector.register { RootFeedsRepository(injector: $0) }
        injector.register { PostsRepository(injector: $0) }
        injector.register { CommentsRepository(injector: $0) }
        injector.register { RepliesRepository(injector: $0) }
        injector.register { UserCommentsRepository(injector: $0) }
        injector.register { ReactionsRepository(injector: $0) }
        injector.register { TopicsRepository(injector: $0) }
        injector.register { ModerationRepository(injector: $0) }
        injector.register { ExternalLinksRepository(injector: $0, apiKey: apiKey) }
        injector.register { ContentTranslationPreferenceRepositoryDefault(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { VideosRepository(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }

        // Feed
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }

        // Database
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { RootFeedsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { TopicsDatabase(injector: $0) }

        // Connection mode related instanciations
        let appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>
        switch connectionMode {
        case .octopus:
            injector.register { MagicLinkMonitorDefault(injector: $0) }
            injector.register { MagicLinkConnectionRepository(connectionMode: connectionMode, injector: $0) }
            appManagedFields = []
        case let .sso(config):
            injector.register { SSOConnectionRepository(connectionMode: connectionMode, injector: $0) }
            injector.register { ClientUserProfileDatabase(injector: $0) }
            appManagedFields = config.appManagedFields
        }
        injector.register { UserDataCleanerMonitor(injector: $0) }
        injector.register { ProfileRepositoryDefault(appManagedFields: appManagedFields, injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: appManagedFields, injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }

        // Validators
        injector.register { _ in Validators(appManagedFields: appManagedFields) }

        // Tracking
        injector.register { _ in trackingCoreDataStack }
        injector.register { EventsDatabase(injector: $0) }
        injector.register { TrackingRepository(injector: $0, forceReset: cleanAfterCommunitySwitch) }
        injector.register { AppSessionMonitor(injector: $0) }
        injector.register { TrackingEventsSendingMonitor(injector: $0) }
        injector.register { OctopusDrivenLoginMonitor(injector: $0) }

        // Notifications
        injector.register { _ in UserNotificationCenterProviderDefault() }
        injector.register { NotificationsDatabase(injector: $0) }
        injector.register { NotificationSettingsDatabase(injector: $0) }
        injector.register { NotificationsRepository(injector: $0) }

        // Config
        injector.register { CommunityAccessMonitor(injector: $0) }

        // Start monitors
        injector.getInjected(identifiedBy: Injected.networkMonitor).start()
        injector.getInjected(identifiedBy: Injected.appStateMonitor).start()
        injector.getInjected(identifiedBy: Injected.appSessionMonitor).start()
        injector.getInjected(identifiedBy: Injected.communityAccessMonitor).start()
        injector.getInjected(identifiedBy: Injected.trackingEventsSendingMonitor).start()
        injector.getInjected(identifiedBy: Injected.octopusDrivenLoginMonitor).start()
        switch connectionMode {
        case .octopus:
            injector.getInjected(identifiedBy: Injected.magicLinkMonitor).start()
        case .sso:
            break
        }
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).start()
        injector.getInjected(identifiedBy: Injected.entitlementMonitor).start()
        injector.getInjected(identifiedBy: Injected.languageChangedMonitor).start()
        injector.getInjected(identifiedBy: Injected.postChildChangeMonitor).start()
        injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider).start()
        injector.getInjected(identifiedBy: Injected.userDataCleanerMonitor).start()

        // Set vars
        connectionRepository = injector.getInjected(identifiedBy: Injected.connectionRepository)
        rootFeedsRepository = injector.getInjected(identifiedBy: Injected.rootFeedsRepository)
        postsRepository = injector.getInjected(identifiedBy: Injected.postsRepository)
        commentsRepository = injector.getInjected(identifiedBy: Injected.commentsRepository)
        repliesRepository = injector.getInjected(identifiedBy: Injected.repliesRepository)
        userCommentsRepository = injector.getInjected(identifiedBy: Injected.userCommentsRepository)
        topicsRepository = injector.getInjected(identifiedBy: Injected.topicsRepository)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        validators = injector.getInjected(identifiedBy: Injected.validators)
        moderationRepository = injector.getInjected(identifiedBy: Injected.moderationRepository)
        reactionsRepository = injector.getInjected(identifiedBy: Injected.reactionsRepository)
        externalLinksRepository = injector.getInjected(identifiedBy: Injected.externalLinksRepository)
        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        notificationsRepository = injector.getInjected(identifiedBy: Injected.notificationsRepository)
        configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        contentTranslationPreferenceRepository = injector.getInjected(identifiedBy: Injected.contentTranslationPreferenceRepository)
        toastsRepository = injector.getInjected(identifiedBy: Injected.toastsRepository)
        videosRepository = injector.getInjected(identifiedBy: Injected.videosRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        octopusDrivenLoginMonitor = injector.getInjected(identifiedBy: Injected.octopusDrivenLoginMonitor)
    }

    public func cleanupBeforeCommunitySwitch() async throws {
        // close sessions
        injector.getInjected(identifiedBy: Injected.appSessionMonitor).stop()

        // send remaining events, then stop the monitor: the tracking store is torn down at the end of
        // this function while this core is still alive (it is only released once the caller replaces it),
        // and a send in flight would then `save()` on a coordinator whose store is gone. CoreData raises
        // an ObjC exception there, which `try` cannot catch — the app aborts.
        do {
            try await injector.getInjected(identifiedBy: Injected.trackingEventsSendingMonitor).sendAllEvents()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Sending all pending events failed: \(error)") }
        }
        injector.getInjected(identifiedBy: Injected.trackingEventsSendingMonitor).stop()

        // disconnecting user
        do {
            try await connectionRepository.logout(preventReconnection: true)
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Disconnecting user failed: \(error)") }
        }

        // Cleaning user related data
        if #available(iOS 14, *) { Logger.other.debug("Cleaning user data") }
        do {
            try await injector.getInjected(identifiedBy: Injected.userDataCleanerMonitor).forceClean()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Cleaning user data failed: \(error)") }
        }

        // Cleaning cached files
        if #available(iOS 14, *) { Logger.other.debug("Cleaning cached files") }
        do {
            try OctopusFileStorageProvider.clearCachedFolder()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Deleting cached files failed: \(error)") }
        }

        // Cleaning db
        if #available(iOS 14, *) { Logger.other.debug("Cleaning db files") }
        do {
            let modelCoreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
            try modelCoreDataStack.teardown()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Cleaning model db files failed: \(error)") }
        }

        do {
            let configCoreDataStack = injector.getInjected(identifiedBy: Injected.configCoreDataStack)
            try configCoreDataStack.teardown()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Cleaning config db files failed: \(error)") }
        }

        do {
            let trackingCoreDataStack = injector.getInjected(identifiedBy: Injected.trackingCoreDataStack)
            try trackingCoreDataStack.teardown()
        } catch {
            if #available(iOS 14, *) { Logger.other.debug("Cleaning tracking db files failed: \(error)") }
        }

        // Last, so the steps above still run against monitors that are alive, exactly as before.
        stopAllMonitors()
    }

    deinit {
        stopAllMonitors()
    }

    /// Cancels every monitor's subscriptions.
    ///
    /// Called from `deinit`, and from `cleanupBeforeCommunitySwitch()` because `deinit` is not
    /// guaranteed to come: a switch replaces this core, but replacing it does not release it. A screen
    /// built on it can still be held by SwiftUI — a view model whose Combine subscription keeps a
    /// profile, its feed, its feed manager and, at the end of that chain, this core's remote client —
    /// and a core kept alive that way keeps monitors subscribed to the community it was built for.
    /// Stopping them during the switch makes the previous core silent whoever still holds it.
    ///
    /// Every `stop()` is idempotent, so the two monitors the cleanup stops earlier, for sequencing
    /// reasons of their own, are safely stopped again here.
    private func stopAllMonitors() {
        injector.getInjected(identifiedBy: Injected.octopusDrivenLoginMonitor).stop()
        injector.getInjected(identifiedBy: Injected.userDataCleanerMonitor).stop()
        injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider).stop()
        injector.getInjected(identifiedBy: Injected.postChildChangeMonitor).stop()
        injector.getInjected(identifiedBy: Injected.languageChangedMonitor).stop()
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).stop()
        injector.getInjected(identifiedBy: Injected.entitlementMonitor).stop()
        switch connectionMode {
        case .octopus:
            injector.getInjected(identifiedBy: Injected.magicLinkMonitor).stop()
        case .sso:
            break
        }
        injector.getInjected(identifiedBy: Injected.trackingEventsSendingMonitor).stop()
        injector.getInjected(identifiedBy: Injected.communityAccessMonitor).stop()
        injector.getInjected(identifiedBy: Injected.appSessionMonitor).stop()
        injector.getInjected(identifiedBy: Injected.appStateMonitor).stop()
        injector.getInjected(identifiedBy: Injected.networkMonitor).stop()
    }
}
