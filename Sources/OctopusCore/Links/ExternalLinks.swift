//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

public enum ExternalLinks {
    public static let communityGuidelines = URL(string: "url.communityGuidelines".localized)!
    public static let privacyPolicy = URL(string: "url.privacyPolicy".localized)!
    public static let termsOfUse = URL(string: "url.termsOfUse".localized)!
    public static let reportIssue = URL(string: "url.reportIssue".localized)!
    public static let faq = URL(string: "url.faq".localized)!
    public static let contactUs = URL(string: "mailto:\(CommunityInfos.email)")!
}

private extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: "ExternalLinks", bundle: Bundle.module, comment: "")
    }
}
