//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// This class is a singleton that provides an instance of the Octopus SDK.
///
/// To test with your own API Key, you will need to modify the way to init the SDK accordingly to your community
/// configuration in the function `initializeSDK()`
class OctopusSDKProvider {

    static let instance = OctopusSDKProvider()

    private(set) var octopus: OctopusSDK!
    @Published var clientLoginRequired = false
    @Published var clientModifyUserField: ConnectionMode.SSOConfiguration.ProfileField?
    @Published var clientModifyUserAsked = false

    private var storage = [AnyCancellable]()

    private init() {
        initializeSDK()

        NotificationManager.instance.$notificationDeviceToken
            .sink { [unowned self] notificationDeviceToken in
                guard let notificationDeviceToken else { return }
                print("Setting notification device token to octopus SDK")
                octopus.set(notificationDeviceToken: notificationDeviceToken)
            }.store(in: &storage)
    }

    private func initializeSDK() {
        guard !DefaultValuesProvider.internalDemoMode else {
            // only used for internal demo mode, please ignore
            initializeSDKForInternalUsage()
            return
        }

        // MODIFY THE FOLLOWING CODE TO MATCH YOUR COMMUNITY CONFIGURATION:
        initializeSdkInSSOWithNoFieldsAssociated()
        // initializeSdkInSSOFullAssociated()
        // initializeSdkInSSOWithSomeFieldsAssociated
        // initializeSdkWithOctopusAuth
    }
    
    /// Initialize the Octopus SDK in SSO with all fields that are app managed (i.e. fully associated)
    private func initializeSdkInSSOFullAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                appManagedFields: Set(ConnectionMode.SSOConfiguration.ProfileField.allCases),
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }, modifyUser: { [weak self] in
                    self?.clientModifyUserField = $0
                    self?.clientModifyUserAsked = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in SSO with some fields that are app managed (i.e. associated)
    private func initializeSdkInSSOWithSomeFieldsAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                appManagedFields: [.nickname, .picture], // EDIT THE ASSOCIATED FIELDS HERE
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }, modifyUser: { [weak self] in
                    self?.clientModifyUserField = $0
                    self?.clientModifyUserAsked = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in SSO with no app managed fields (i.e. SSO Dissociated)
    private func initializeSdkInSSOWithNoFieldsAssociated() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .sso(.init(
                loginRequired: { [weak self] in
                    self?.clientLoginRequired = true
                }
            ))
        )
    }

    /// Initialize the Octopus SDK in Octopus auth (i.e. authentification will be done with a MagicLink)
    private func initializeSdkWithOctopusAuth() {
        octopus = try! OctopusSDK(
            apiKey: APIKeys.apiKey,
            connectionMode: .octopus(deepLink: nil) // EDIT THE DEEPLINK IF YOU WANT TO
        )
    }

    private func initializeSDKForInternalUsage() {
        guard let sdkConfig = SDKConfigManager.instance.sdkConfig else {
            fatalError("SDK config should be set before initializing the SDK")
        }
        let connectionMode: ConnectionMode = switch sdkConfig.authKind {
        case .octopus: .octopus(deepLink: "com.octopuscommunity.sample://magic-link")
        case let .sso(appManagedFields, _):
                .sso(
                    .init(
                        appManagedFields: Set(appManagedFields.map {
                            return switch $0 {
                            case .nickname: .nickname
                            case .bio: .bio
                            case .picture: .picture
                            }
                        }), loginRequired: { [weak self] in
                            self?.clientLoginRequired = true
                        }, modifyUser: { [weak self] in
                            self?.clientModifyUserField = $0
                            self?.clientModifyUserAsked = true
                        }
                    )
                )
        }
        let apiKey = switch sdkConfig.authKind {
        case .octopus: APIKeys.octopusAuth
        case let .sso(appManagedFields, forceLoginOnStrongActions):
            if appManagedFields.isEmpty {
                if forceLoginOnStrongActions {
                    APIKeys.ssoNoManagedFieldsForceLogin
                } else {
                    APIKeys.ssoNoManagedFields
                }
            } else if Set(appManagedFields) == Set(SDKConfig.ProfileField.allCases) {
                APIKeys.ssoAllManagedFields
            } else {
                APIKeys.ssoSomeManagedFields
            }
        }

        printSdkCreation(connectionMode: connectionMode)
        octopus = try! OctopusSDK(apiKey: apiKey, connectionMode: connectionMode)
    }

    private func printSdkCreation(connectionMode: ConnectionMode) {
        switch connectionMode {
        case .octopus: print("Create SDK with connection mode: Octopus")
        case let .sso(config):
            if config.appManagedFields.isEmpty {
                print("Create SDK with connection mode: SSO with no app managed fields")
            } else if config.appManagedFields == Set(ConnectionMode.SSOConfiguration.ProfileField.allCases) {
                print("Create SDK with connection mode: SSO with all managed fields")
            } else {
                print("Create SDK with connection mode: SSO with some managed fields")
            }
        }
    }
}
