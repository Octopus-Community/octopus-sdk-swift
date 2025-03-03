# Swift Package of the Octopus SDK  

## Purpose
The purpose of this Swift Package is to provide every feature of Octopus Community to your Swift based apps:
add your own social network within your app. We handle all the work for you: UI, moderation, storage…
You can easily integrate all of these features with our Android and iOS SDKs.

## How to use
If you want to use OctopusSDK, follow our [official documentation](https://www.notion.so/octopuscommunity/iOS-SDK-Setup-Guide-1a1d0ed811a980e8896bdf540bac6d6f) for integration.

## How to run the tests
We provide tests in the Swift Package.
To run them:
- run the tests with Xcode

## Architecture

Swift SDK is divided into two public products:

- `OctopusUI` that contains all the code related to the UI
- `Octopus` that contains the model objects.

`OctopusUI` exposes `OctopusHomeScreen` and `OctopusTheme`.

- `OctopusHomeScreen` is a SwiftUI view with a root NavigationView.
- `OctopusTheme` is the theme used by all the views of `OctopusUI`. This theme can be overridden or left as is.
- `View`s and `ViewModel`s are all the views available inside the UI SDK. They are, for the moment, private. An example is `PostListView` and `PostListViewModel` that display the list of posts.

`Octopus` exposes `OctopusSDK`.

- `OctopusSDK` is the main object of the Octopus SDK. It is initialized with the API key that uniquely identifies a client. It creates all the other main objects of the SDK. These objects are created and retained using a dependency injection module. They are mainly `Repositories`, `Monitors`, `Databases interfaces`  and `Server interfaces`.
- `ConnectionMode` is a configuration of the SDK. It is either `octopus` for a user connection handled by us, or `sso` for a user connection based on your user management.
- `ClientUser` is only used when `connectionMode` is `sso`. It represents how the SDK will be fed with your user information.


For the moment, those other objects are not public, so you should not use them (as long as they are in the OctopusCore package).
Here is a quick explanation of what they do, just so you can get a better understanding of how the whole SDK works.

- `Repositories` are the public (but yet private to you!) interface for each kind of interaction with the model layer. For example PostsRepository, ConnectionRepository…
- `Monitors` are objects that are observing a state and reacts accordingly. They are private to the SDK. They can be `NetworkMonitor` that monitors the network connectivity or `MagicLinkMonitor` that listen for app states (whether in foreground, with a magic link pending…) to query and update the magic link state. `Monitors` are generally objects that lives on their own and their only API is `start` and `stop`.
- `Database interfaces` are objects that can do CRUD operations on a CoreDatabase stack
- `Server interfaces` are part of another private target: `RemoteClient`. They are the interface to call the GRPC services.
