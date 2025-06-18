//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A provisionning profile embbeded in the app
/// Only present on debug builds, not on production ones (AppStore, TestFlight).
struct ProvisionningProfile: Decodable {
    let entitlements: Entitlements

    private enum CodingKeys : String, CodingKey {
        case entitlements = "Entitlements"
    }

    struct Entitlements: Decodable {
        let apsEnvironment: Environment?

        private enum CodingKeys: String, CodingKey {
            // More infos here: https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment
            case apsEnvironment = "aps-environment"
        }

        enum Environment: String, Decodable {
            case development
            case production
        }

        init(apsEnvironment: Environment?) {
            self.apsEnvironment = apsEnvironment
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let apsEnvironment = (try? container.decode(Environment.self, forKey: .apsEnvironment))

            self.init(apsEnvironment: apsEnvironment)
        }
    }

    static func read() -> ProvisionningProfile? {
        guard let provisionningProfilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return nil
        }
        // Load the file as a plist
        guard let plistDataString = try? NSString.init(
            contentsOfFile: provisionningProfilePath,
            encoding: String.Encoding.isoLatin1.rawValue) else { return nil }

        // Only read the plist part
        let scanner = Scanner(string: plistDataString as String)
        guard scanner.scanUpToString("<plist") != nil,
              let extractedPlist = scanner.scanUpToString("</plist>"),
              let plist = extractedPlist.appending("</plist>").data(using: .isoLatin1) else { return nil }

        let decoder = PropertyListDecoder()
        return try? decoder.decode(ProvisionningProfile.self, from: plist)
    }
}
