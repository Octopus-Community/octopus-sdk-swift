# Octopus SDK for iOS

[![Release](https://img.shields.io/github/v/release/Octopus-Community/octopus-sdk-swift?label=release)](https://github.com/Octopus-Community/octopus-sdk-swift/releases)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-F05138?logo=swift&logoColor=white)](https://www.swift.org/documentation/package-manager/)
[![CocoaPods](https://img.shields.io/cocoapods/v/OctopusCommunityUI?label=CocoaPods)](https://cocoapods.org/pods/OctopusCommunityUI)
[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B-lightgrey?logo=apple)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/license-Octopus%20Community%20Mobile%20SDK-lightgrey)](LICENSE.md)

A white-label, moderated in-app community — feed, groups, posts with images and polls,
comments, reactions, profiles and notifications — as native SwiftUI screens themed to your app.

## What you get

- **Native SwiftUI, no web view.** One view, `OctopusHomeScreen`, opens the whole community;
  colors, fonts, icons and logo come from your own design through `OctopusTheme`.
- **Hosted backend.** Octopus runs the servers, storage, moderation and analytics behind the
  community; your app ships the SDK and an API key.
- **Your accounts.** Connect your signed-in users with SSO (a JWT signed by your backend). Profile fields can stay owned by your app.
- **Hooks into your app.** Attach a discussion to your own content (bridge), forward APNs push
  notifications, and observe the unread count of internal notifications, the connected profile and SDK events through
  Combine.

## Requirements

| | Minimum |
|---|---|
| iOS | 13.0 |
| Xcode | 16 (Swift tools 6.0) |
| UI | SwiftUI (host it in UIKit with a `UIHostingController`) |
| API key | One per community — see [Sample app](#sample-app) for a free sandbox key |

## Installation

**Swift Package Manager** (recommended). In Xcode, *File → Add Package Dependencies…*, paste
`https://github.com/Octopus-Community/octopus-sdk-swift.git` and add both the `Octopus` and
`OctopusUI` products to your target. In a `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Octopus-Community/octopus-sdk-swift.git", from: "1.13.2"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "Octopus", package: "octopus-sdk-swift"),
        .product(name: "OctopusUI", package: "octopus-sdk-swift"),
    ]),
]
```

**CocoaPods** is also published (`pod 'OctopusCommunity'` and `pod 'OctopusCommunityUI'`) but
needs extra Podfile settings — see [Install the SDK](https://doc.octopuscommunity.com/SDK/sso/#install-the-sdk).

`Octopus` alone gives you the API (connection, state, bridge, push) without any UI; add
`OctopusUI` to display the community.

## Quickstart

Create the SDK once, as early as possible, and present the community:

```swift
import SwiftUI
import Octopus
import OctopusUI

@main
struct MyApp: App {
    // Keep a single instance for the app's lifetime. Handle the thrown error in a real app.
    private let octopus = try! OctopusSDK(apiKey: "YOUR_API_KEY")
    @State private var showCommunity = false

    var body: some Scene {
        WindowGroup {
            Button("Open community") { showCommunity = true }
                .fullScreenCover(isPresented: $showCommunity) {
                    OctopusHomeScreen(octopus: octopus, navigationMode: .navigationStack)
                }
        }
    }
}
```

The default connection mode lets Octopus handle sign-in, so no callback is needed. To connect
your own signed-in users, pass `connectionMode: .sso(.init(loginRequired: { … }))` and call
`octopus.connectUser(_:tokenProvider:)` with a token from your backend — see
[Link your user to the SDK](https://doc.octopuscommunity.com/SDK/sso/#link-your-user-to-the-sdk).
Keep `navigationMode: .navigationStack` whenever the screen sits in a modal (`.sheet`,
`.fullScreenCover`, a Flutter or React Native modal route): the default navigation container can
drop in-app pushes there. Pushed onto your own navigation stack, the default `.automatic` is right.

## Sample app

[`Sample/`](Sample) is a SwiftUI app covering Octopus sign-in and the SSO variants, theming,
the bridge, push notifications, events and opening a specific screen, one scenario each.

```bash
git clone https://github.com/Octopus-Community/octopus-sdk-swift.git && cd octopus-sdk-swift
cp Sample/OctopusSample/Config/secrets.placeholder.xcconfig Sample/OctopusSample/Config/secrets.xcconfig
open Sample/OctopusSample.xcworkspace   # set OCTOPUS_API_KEY and CLIENT_USER_TOKEN_SECRET in secrets.xcconfig, then run OctopusSample
```

Set `OCTOPUS_API_KEY` and `CLIENT_USER_TOKEN_SECRET` in `secrets.xcconfig`.

- **`OCTOPUS_API_KEY`** identifies your community. The SDK sends it on every call to the Octopus
  backend, so nothing works without it.
- **`CLIENT_USER_TOKEN_SECRET`** is the HMAC-SHA256 key your backend uses to sign the JWT that
  tells Octopus who the connected user is — only needed if your community runs in SSO mode. The
  sample signs that token locally, in `TokenProvider`, purely for convenience; your app should
  fetch it from your own backend instead
  ([Generate a signed JWT for SSO](https://doc.octopuscommunity.com/backend/sso/)).

Both values come from your Octopus dashboard. You can get free access by requesting it from the
form on [octopuscommunity.com](https://www.octopuscommunity.com).

## Links

- [SDK Setup Guide](https://doc.octopuscommunity.com/SDK/sso/) — SSO, opening a specific screen,
  theming, push notifications, analytics, groups, bridges, multi-community
- [Documentation](https://doc.octopuscommunity.com) — cross-platform guides, JWT and SSO backend
  setup
- [Releases](https://github.com/Octopus-Community/octopus-sdk-swift/releases) — release notes
- [ARCHITECTURE.md](ARCHITECTURE.md) — module layout; open `Package.swift` in Xcode to run the
  package tests
- [Issues](https://github.com/Octopus-Community/octopus-sdk-swift/issues)
- Other Octopus SDKs: [Android](https://github.com/Octopus-Community/octopus-sdk-android) ·
  [Flutter](https://github.com/Octopus-Community/octopus-sdk-flutter) ·
  [React Native](https://github.com/Octopus-Community/octopus-sdk-react-native) ·
  [Unity](https://github.com/Octopus-Community/octopus-sdk-unity)

## License

Distributed under the **Octopus Community Mobile SDK License** — see [LICENSE.md](LICENSE.md).
