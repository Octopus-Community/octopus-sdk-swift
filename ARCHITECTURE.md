## Architecture of the SDK

Octopus Community Swift SDK is divided into two public libraries:

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
- `Server interfaces` are part of another private target: `OctopusRemoteClient`. They are the interface to call the GRPC services.

## Architecture of the Samples

Due to the fact that the samples can handle multiple ways of initializing the SDK (due to the support of different connection mode), we are using the OctopusSDKProvider to be sure that there is only one instance of the SDK at a time.

You might notice a weird way of displaying modal SDK UI in `SampleRootView`. Because SwiftUI is behaving weirdly when having a TabView, a NavigationStack and a fullScreenCover, we are opening the fullScreenCover outside of the TabView and the NavigationStack (or NavigationView).
Not doing so will result in weird behaviors when putting the app in background. Some views might be dismissed and some ViewModels are re-created.
