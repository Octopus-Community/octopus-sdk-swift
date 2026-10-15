//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import Octopus

/// This class is a singleton that shows how to intercept links clicked inside the community to decide whether to let
/// Octopus Community handle them or to handle within the app.
/// For example, if your app wants to intercept links that would go to your website and instead open a screen directly
/// in the app, you can do it here.
class URLManager {
    static let instance = URLManager()

    private init() { }

    /// Function called when the Octopus SDK is created.
    func set(octopus: OctopusSDK) {
        octopus.set(onNavigateToURLCallback: { url in
            /// Block that will be called when the user is opening urls inside the SDK.
            /// These links can appear in Posts, Comments or Replies contents, and also in the CTA of the Posts with
            /// CTAs.
            /// - Parameter url: the url to open
            /// - Returns: `.handledByApp` if the link is handled by the app, `.handledByOctopus` if the link should be
            /// opened normally by Octopus.
            ///
            /// The sample reads the policy chosen in Settings › Host app integration at every tap, so a change
            /// applies to the next link. Your app would usually only keep the rule of `HostURLPolicy.sampleRule`.
            switch HostIntegrationStore.instance.urlPolicy.decision(for: url) {
            case let .openInApp(appURL):
                UIApplication.shared.open(appURL)
                // link has been handled by app, let the Octopus SDK know that it should do nothing more
                return .handledByApp
            case .letOctopusOpen:
                // Let the SDK handle the link by returning `handledByOctopus`
                return .handledByOctopus
            }
        })
    }
}
