import Foundation
import OctopusRemoteClient
import OctopusGrpcModels
import Combine
import OctopusDependencyInjection

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDKCore: ObservableObject {
    public let connectionRepository: ConnectionRepository
    public let profileRepository: ProfileRepository
    public let rootFeedsRepository: RootFeedsRepository
    public let postsRepository: PostsRepository
    public let commentsRepository: CommentsRepository
    public let repliesRepository: RepliesRepository
    public let topicsRepository: TopicsRepository
    public let moderationRepository: ModerationRepository
    public let externalLinksRepository: ExternalLinksRepository
    public let trackingRepository: TrackingRepository
    public let notificationsRepository: NotificationsRepository
    public let configRepository: ConfigRepository
    public let contentTranslationPreferenceRepository: ContentTranslationPreferenceRepository

    public let validators: Validators

    private let injector: Injector
    private let connectionMode: ConnectionMode

    /// Constructor
    /// - Parameter apiKey: the API key that identifies your project
    public init(apiKey: String, connectionMode: ConnectionMode, injector: Injector) throws {
        self.connectionMode = connectionMode
        self.injector = injector
        let installIdProvider = InstallIdProvider()
        let modelCoreDataStack = try ModelCoreDataStack()
        let trackingCoreDataStack = try TrackingCoreDataStack()
        let configCoreDataStack = try ConfigCoreDataStack()
        injector.register { _ in SecuredStorageDefault(apiKey: apiKey, isNewInstall: installIdProvider.isNewInstall) }
        injector.register { UserDataStorage(injector: $0) }
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let remoteClient = try GrpcClient(
            apiKey: apiKey, sdkVersion: version, installId: installIdProvider.installId,
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
        injector.register { PostChildChangeMonitor(injector: $0) }
        injector.register { LanguageChangedMonitor(injector: $0) }
        injector.register { BlockedUserIdsProviderDefault(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }

        // Repository
        injector.register { ConfigRepositoryDefault(injector: $0) }
        injector.register { RootFeedsRepository(injector: $0) }
        injector.register { PostsRepository(injector: $0) }
        injector.register { CommentsRepository(injector: $0) }
        injector.register { RepliesRepository(injector: $0) }
        injector.register { TopicsRepository(injector: $0) }
        injector.register { ModerationRepository(injector: $0) }
        injector.register { ExternalLinksRepository(injector: $0, apiKey: apiKey) }
        injector.register { ContentTranslationPreferenceRepository(injector: $0) }

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
        injector.register { TrackingRepository(injector: $0) }
        injector.register { AppSessionMonitor(injector: $0) }
        injector.register { TrackingEventsSendingMonitor(injector: $0) }

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
        switch connectionMode {
        case .octopus:
            injector.getInjected(identifiedBy: Injected.magicLinkMonitor).start()
        case .sso:
            break
        }
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).start()
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
        topicsRepository = injector.getInjected(identifiedBy: Injected.topicsRepository)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        validators = injector.getInjected(identifiedBy: Injected.validators)
        moderationRepository = injector.getInjected(identifiedBy: Injected.moderationRepository)
        externalLinksRepository = injector.getInjected(identifiedBy: Injected.externalLinksRepository)
        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        notificationsRepository = injector.getInjected(identifiedBy: Injected.notificationsRepository)
        configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        contentTranslationPreferenceRepository = injector.getInjected(identifiedBy: Injected.contentTranslationPreferenceRepository)
    }

    deinit {
        injector.getInjected(identifiedBy: Injected.userDataCleanerMonitor).stop()
        injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider).stop()
        injector.getInjected(identifiedBy: Injected.postChildChangeMonitor).stop()
        injector.getInjected(identifiedBy: Injected.languageChangedMonitor).stop()
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).stop()
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
