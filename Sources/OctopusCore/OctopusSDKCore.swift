import Foundation
import RemoteClient
import GrpcModels
import Combine
import DependencyInjection

/// Octopus Community main model object.
/// This object holds a reference on all the repositories.
public class OctopusSDKCore: ObservableObject {
    public let connectionRepository: ConnectionRepository
    public let profileRepository: ProfileRepository
    public let rootFeedsRepository: RootFeedsRepository
    public let postsRepository: PostsRepository
    public let commentsRepository: CommentsRepository
    public let topicsRepository: TopicsRepository
    public let moderationRepository: ModerationRepository

    public let validators: Validators

    private let injector: Injector
    private let connectionMode: ConnectionMode

    /// Constructor
    /// - Parameter apiKey: the API key that identifies your project
    public init(apiKey: String, connectionMode: ConnectionMode, injector: Injector) throws {
        self.connectionMode = connectionMode
        self.injector = injector
        let coreDataStack = try CoreDataStack()
        injector.register { _ in SecuredStorageDefault(apiKey: apiKey) }
        injector.register { UserDataStorage(injector: $0) }
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        let remoteClient = try GrpcClient(
            apiKey: apiKey, sdkVersion: version,
            updateTokenBlock: { [userDataStorage] newToken in
                guard let userData = userDataStorage.userData else { return }
                let newUserData = UserDataStorage.UserData(id: userData.id, jwtToken: newToken)
                userDataStorage.store(userData: newUserData)
            })
        injector.register { _ in remoteClient }
        injector.register { _ in coreDataStack }
        injector.register { _ in NetworkMonitorDefault() }
        injector.register { _ in AppStateMonitorDefault() }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { UserProfileFetchMonitorDefault(injector: $0) }
        injector.register { PostChildChangeMonitor(injector: $0) }
        injector.register { BlockedUserIdsProviderDefault(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }

        // Repository
        injector.register { RootFeedsRepository(injector: $0) }
        injector.register { PostsRepository(injector: $0) }
        injector.register { CommentsRepository(injector: $0) }
        injector.register { TopicsRepository(injector: $0) }
        injector.register { ModerationRepository(injector: $0) }

        // Feed
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }

        // Database
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { RootFeedsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { TopicsDatabase(injector: $0) }

        // Connection mode related instanciations
        let appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>
        switch connectionMode {
        case .octopus:
            injector.register { MagicLinkMonitorDefault(injector: $0) }
            injector.register { MagicLinkConnectionRepository(connectionMode: connectionMode, injector: $0) }
            appManagedFields = []
        case let .sso(config):
            injector.register { SSOExchangeTokenMonitorDefault(injector: $0) }
            injector.register { SSOConnectionRepository(connectionMode: connectionMode, injector: $0) }
            injector.register { ClientUserProfileDatabase(injector: $0) }
            appManagedFields = config.appManagedFields
        }
        injector.register { ProfileRepository(appManagedFields: appManagedFields, injector: $0) }

        // Validators
        injector.register { _ in Validators(appManagedFields: appManagedFields) }

        // Start monitors
        injector.getInjected(identifiedBy: Injected.networkMonitor).start()
        injector.getInjected(identifiedBy: Injected.appStateMonitor).start()
        switch connectionMode {
        case .octopus:
            injector.getInjected(identifiedBy: Injected.magicLinkMonitor).start()
        case .sso:
            injector.getInjected(identifiedBy: Injected.ssoExchangeTokenMonitor).start()
        }
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).start()
        injector.getInjected(identifiedBy: Injected.postChildChangeMonitor).start()
        injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider).start()

        // Set vars
        connectionRepository = injector.getInjected(identifiedBy: Injected.connectionRepository)
        rootFeedsRepository = injector.getInjected(identifiedBy: Injected.rootFeedsRepository)
        postsRepository = injector.getInjected(identifiedBy: Injected.postsRepository)
        commentsRepository = injector.getInjected(identifiedBy: Injected.commentsRepository)
        topicsRepository = injector.getInjected(identifiedBy: Injected.topicsRepository)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        validators = injector.getInjected(identifiedBy: Injected.validators)
        moderationRepository = injector.getInjected(identifiedBy: Injected.moderationRepository)
    }

    deinit {
        injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider).stop()
        injector.getInjected(identifiedBy: Injected.postChildChangeMonitor).stop()
        injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor).stop()
        switch connectionMode {
        case .octopus:
            injector.getInjected(identifiedBy: Injected.magicLinkMonitor).stop()
        case .sso:
            injector.getInjected(identifiedBy: Injected.ssoExchangeTokenMonitor).stop()
        }
        injector.getInjected(identifiedBy: Injected.appStateMonitor).stop()
        injector.getInjected(identifiedBy: Injected.networkMonitor).stop()
    }
}
