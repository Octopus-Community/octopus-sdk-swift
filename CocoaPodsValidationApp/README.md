## CocoaPodsValidationApp

This app is intended to provide a Podfile example to install the Octopus SDK using CocoaPods.
We highly recommend you to use SPM instead, because CocoaPods is starting to be less and less used, some libraries are not available anymore.
This is the case of SwiftGrpc on which the Octopus SDK has built its backend exchanges. 
Hence, if you use the SDK using Cocoapods, you will be using an old version of SwiftGrpc.

### How to run the example
Run `pod install`, then open the workspace and run the projet.

### Technical notes
In order to compile, the iOS deployment target is set to iOS 14 and the project `ENABLE_USER_SCRIPT_SANDBOXING` is set to `NO`. 
This is done in the podfile and you should do the same in your own project. 
