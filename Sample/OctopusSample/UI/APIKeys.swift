//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum APIKeys {
    static let apiKey: String = Bundle.main.infoDictionary!["OCTOPUS_API_KEY"] as! String

    // The following values are only used in internal demo mode
    static let octopusAuth = Bundle.main.infoDictionary!["OCTOPUS_MAGICLINK_FORCED_LOGIN_API_KEY"] as! String
    static let ssoNoManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_NO_MANAGED_FIELDS_NO_FORCED_LOGIN_API_KEY"] as! String
    static let ssoNoManagedFieldsForceLogin = Bundle.main.infoDictionary!["OCTOPUS_SSO_NO_MANAGED_FIELDS_FORCED_LOGIN_API_KEY"] as! String
    static let ssoSomeManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_SOME_MANAGED_FIELDS_FORCED_LOGIN_API_KEY"] as! String
    static let ssoAllManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_ALL_MANAGED_FIELDS_FORCED_LOGIN_API_KEY"] as! String
}
