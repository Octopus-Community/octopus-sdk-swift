//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum APIKeys {
    static let octopusAuth = Bundle.main.infoDictionary!["OCTOPUS_API_KEY"] as! String
    static let ssoNoManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_NO_MANAGED_FIELDS_API_KEY"] as! String
    static let ssoSomeManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_SOME_MANAGED_FIELDS_API_KEY"] as! String
    static let ssoAllManagedFields = Bundle.main.infoDictionary!["OCTOPUS_SSO_ALL_MANAGED_FIELDS_API_KEY"] as! String
}
