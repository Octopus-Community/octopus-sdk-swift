# Swift Package of the Octopus SDK  

## Purpose
The purpose of this Swift Package is to provide every feature of Octopus Community to your Swift based apps:
add your own social network within your app. We handle all the work for you: UI, moderation, storage…
You can easily integrate all of these features with our Android and iOS SDKs.

## How to use
If you want to use OctopusSDK, follow our [official documentation](https://octopus-documentation.pages.dev/) for integration.

### Hosting `OctopusHomeScreen` inside a modal
By default `OctopusHomeScreen` uses a legacy `NavigationView`. When the screen is presented inside a modal that
reparents its hosting controller — a SwiftUI `.sheet` / `.fullScreenCover`, or a Flutter / React Native modal route —
that legacy navigation can silently drop in-app pushes (e.g. tapping a post no longer opens its detail).

If you host the SDK that way, opt into a `NavigationStack` (iOS 16+, with a legacy fallback below iOS 16):

```swift
OctopusHomeScreen(octopus: octopus, navigationMode: .navigationStack)
```

Pushed into the navigation stack normally (no modal), the default `.automatic` mode is the right choice.

## How to run the tests
We provide tests in the Swift Package.
To run them:
- run the tests with Xcode

## Architecture

If you want to know more about how the SDK's architecture, [here is a document](ARCHITECTURE.md) that explains it.
