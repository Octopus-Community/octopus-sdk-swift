# Changelog

Notable changes to the Octopus iOS SDK, one section per version, most recent first. History for
the versions before 1.14.0 lives in the
[GitHub Releases](https://github.com/Octopus-Community/octopus-sdk-swift/releases).

## 1.15.1 — 2026-10-30

### Fixed

- **Comment and Reply icons stay still when the app comes back to the foreground.** The icons of the
  Comment and Reply buttons under posts and comments sometimes gave a little bounce when the app
  returned to the foreground with the community on screen, although nothing had changed. They no
  longer animate; the Like button keeps its bounce when a member reacts.
- **Typed text stays readable when the appearance changes.** In the multi-line text fields (post,
  comment and reply composers, poll options, profile bio), the text already typed kept its
  light-mode colour when the device switched to dark mode with the field on screen, which made it
  unreadable on the dark background until the next keystroke. It now follows the appearance at
  once.
- **Red icons for Report and Block in the "•••" menus.** When the host app sets a `.tint` above the
  SDK, the icons of the Report and Block actions of posts, comments, replies and profiles took that
  tint next to their red title. They are now red like their title.
- **Apps without the glass effect.** On iOS 26 and later, in an app that opts out of the glass effect
  (`UIDesignRequiresCompatibility` in its Info.plist), the community screens now draw the opaque
  navigation bar, pinned tabs and bar buttons of earlier iOS versions instead of a mix of both
  designs. On every iOS version without the glass effect, the floating Explore Groups button gets a
  background, so it stays readable over dark content.
  An app built with Xcode 27 and running on iOS 27 gets the glass effect whatever the key says, and
  the community screens now follow it there too.
- **Groups list and profile edition navigation bar in the community background.** Without the glass
  effect (iOS 16 to 18, or an iOS 26 app that opts out of it), the navigation bar of the groups list and
  of the profile edition screen turned white once their content scrolled under it, over a custom
  `background` color. It now takes that background, like the other community screens.
- **Images zoom from a profile's Comments tab.** Tapping the image of a post or of a comment in a
  profile's Comments tab did nothing; it now opens the image full screen, like everywhere else.
- **Repeated images no longer go blank.** When a screen showed the same image more than once, like a
  post repeated for each of a member's comments in their profile's comments, one of the copies could
  stay empty for a few seconds.
- **Bottom margin on devices with a home button.** On iOS 15 and later, when `OctopusHomeScreen`
  goes down to the bottom edge of its window with no safe area there (a device with a home button
  and no tab bar below, or a floating iPad window), the SDK adds 16pt to the `bottomSafeAreaInset`
  you pass, so the "Write a post" button and the profile bubble no longer touch the edge. Nothing
  changes when the home screen ends above something (a tab bar, a bar of your app, the bottom of a
  sheet) or above a home indicator.

## 1.15.0 — 2026-10-15

### Removed

- **Breaking — the navigation types of `OctopusUI`.** `OctopusUI` embeds a copy of
  [NavigationBackport](https://github.com/johnpatrickmorgan/NavigationBackport) for its own screens,
  and that copy was public by accident: `NBNavigationStack`, `NBNavigationLink`, `NBNavigationPath`,
  `NBScreen`, `Navigator`, `PathNavigator`, `UseNavigationStackPolicy`, `NavigationLinkRowStyle`, the
  `nbNavigationDestination` and `nbUseNavigationStack` view modifiers, and the `push`/`pop`/`popTo`
  and `withDelaysIfUnsupported` extensions on `Array`, `Binding` and `ObservableObject`. They are now
  internal. An app that used them imports [NavigationBackport](https://github.com/johnpatrickmorgan/NavigationBackport)
  itself, or uses SwiftUI's `NavigationStack` on iOS 16 and later.
- **Breaking — the Octopus connection mode.** `ConnectionMode.octopus(deepLink:)` is gone, and with it
  the sign-in by email link, the account settings and delete account screens, and the log out entry of
  the profile menu: your app now always owns sign-in, through `ConnectionMode.sso`. `connectionMode`
  is therefore required in `OctopusSDK.init(apiKey:connectionMode:configuration:)` and
  `switchCommunity(apiKey:connectionMode:configuration:)`, where it used to default to `.octopus`.
  A pending email link request left in the Keychain by an earlier version is wiped at launch.

### Deprecated

- The empty list icons of the theme, no longer displayed since 1.14.0:
  `OctopusTheme.Assets.Icons.Content.Post.emptyFeedInGroups`, `emptyFeedInCurrentUserProfile`,
  `emptyFeedInOtherUserProfile`, `OctopusTheme.Assets.Icons.Content.Comment.emptyFeed` and
  `OctopusTheme.Assets.Icons.Profile.emptyNotifications`, along with the initializers taking them: drop
  those arguments, each initializer has an overload without them. Empty lists show the screen states
  instead, customized through `OctopusTheme.Assets.Icons.ScreenStates` (`emptyContent`,
  `emptyNotifications`). Unlike the icons they replace, these illustrations keep their own colors and
  are not tinted.
- The `account`, `logout` and `deleteAccountWarning` settings icons of the theme, which are no longer
  displayed, along with the `OctopusTheme.Assets.Icons.Settings` initializer taking them: use
  `init(help:info:)`.
- The `settingsList`, `settingsAccount` and `deleteAccount` screens of `OctopusEvent.Screen`, which are
  no longer emitted (`settingsList` since 1.13.0, when the settings moved to the profile's menu).

### Added

- **Block after a report.** Once a post, a comment, a reply or a profile is reported, the "Report
  sent" alert offers to block its author. Blocking from a profile report also closes that profile.
- **Themable clear-text icon.** `OctopusTheme.Assets.Icons.Common.clearText`, a filled disc with a cross
  cut out of it, is the button that clears a text field, starting with the nickname field. Override it
  through the new `clearText` parameter of `OctopusTheme.Assets.Icons.Common.init`.
- **Community consent texts.** The labels of the consent sheet, the text under its single checkbox
  and the legal notice under the composers show the wordings the community set in its back-office,
  in the member's language, with links, bold and italic. A field the community leaves empty keeps
  the SDK wording, and communities that set nothing are unchanged. A link in these texts opens its
  URL through the same handling as every other link of the SDK, so the callback you registered with
  `set(onNavigateToURLCallback:)` sees it first.
- **Community default avatars.** A member without a picture of their own is drawn with the default
  avatar the community chose in the dashboard: its colors behind the member's initials, or one of
  its images. Removing your picture in the profile editor previews the community default you will
  get. Communities that keep the automatic avatar see no change. Nothing to do in the app.
- **An image and a poll in the same post.** A member can attach an image and a poll to the same
  post: the composer keeps offering the poll once an image is attached, and removing one keeps the
  other. The feed and the post detail show the image above the poll, and VoiceOver reads the image,
  then the poll options. A post carrying both, published from another platform, no longer loses its
  image on iOS.
- **Posts without text.** When a community makes post text optional, a member can publish a post that
  carries an image, with or without a poll, and no text; a body made only of whitespace is sent as no
  text. The feed and the post detail show no empty text area for such a post, and VoiceOver announces
  an image-only post as an image shared by its author. Communities that keep text required are
  unchanged.

### Changed

- The consent sheet scrolls when its content is taller than the screen allows, with its button
  pinned at the bottom, including on iPad, where the button always stays on screen. The legal notice
  under the post, comment and reply composers shows up to five lines, then scrolls: half of the next
  line stays visible to show there is more, and on iOS 17 and later the scroll indicator flashes
  once when the notice appears. It never takes more than 20 % of the window height, so at the
  largest accessibility text sizes it scrolls earlier instead of pushing the composer away.
- **The nickname screen before the first contribution.** A member who has not confirmed a nickname now
  chooses it, and can set their picture, before their first post, comment or reply is sent, which then goes
  on its own; the screen can no longer be skipped. When the community requires it, the field starts empty
  instead of offering the generated nickname, and a taken nickname comes with available suggestions. The
  `validateNickname` screen event now reports this screen. A nickname the host app manages
  (`.nickname` in the SSO `appManagedFields`), or that the community locks, never shows the screen.
- **Breaking — for direct `OctopusCommunityCore` pod users only.** To carry the suggestions of a taken
  nickname, `UpdateProfile.ErrorDetail.alreadyTaken` became `alreadyTaken(suggestions: [String])`. Code
  that builds or compares `.alreadyTaken` must now use `.alreadyTaken(suggestions:)`; `case .alreadyTaken:`
  patterns still compile. This type is not part of the `Octopus` and `OctopusUI` API.
- `OctopusRefreshEntitlementsError.noClientTokenProvider` now means that no `tokenProvider` has been
  registered through `connectUser` yet (for instance right after a relaunch restored the session),
  instead of signalling the Octopus connection mode.
- Each request now tells the backend which SDK family the host app integrates (native, Flutter,
  React Native or Unity) and that SDK's version, so the dashboard can show it. Nothing changes in the
  app and no public API changes.
- The "See translation" toggle of a post now also shows when only its poll options have a
  translation, including on posts whose text is not translated, and switches the text and the poll
  options together.
- **Translations.** The SDK's texts are updated in every supported language. In English, the
  consent checkboxes now refer to the "Terms of Use" instead of the "Terms and Conditions".

### Fixed

- **No nickname choice for a nickname the host app manages.** When the SSO configuration lists
  `.nickname` in `appManagedFields`, a signed-in member is no longer shown the nickname choice screen
  before their first post, comment or reply, even if `forceNicknameChoice` is set: the contribution
  goes on directly, under the nickname the app provides, or under the generated one if the app
  provides none.
- `disconnectUser()` could sign the user in instead of out. When the exchange of their token had failed,
  the SDK kept a guest session but still remembered the user, and the reconnection that follows a
  disconnect then signed them in. The user is now forgotten, the guest session is kept as it is, and a
  ban that came with that user no longer shows on it.
- **Gamification rules sheet sized from its window.** The sheet explaining how to earn points takes
  at most 80 % of the height of the window it is shown in, instead of 80 % of the device's main
  screen, and follows that window when it is rotated or resized. In an iPad window shorter than the
  screen (Stage Manager, windowed apps), it no longer outgrows the window.
- On iOS 13 and 14, a markdown link whose address is not a valid URL (a space or an accented letter
  in it, for instance) crashed the app when shown in a post, a comment or a legal text. Such a link
  now shows as plain text.
- After the member's language changed, the community configuration was reloaded in the previous
  language, and the requests kept that language when the reload failed. Requests now switch to the
  new language first.
- **Navigation bar buttons on iOS 27.** The buttons of the navigation bar (Publish on the post
  creation screen, Save on the profile editing screen, Follow on a group) no longer have their label
  truncated (e.g. "Pub…" in French).
- **Toasts over translucent theme colors.** When the theme's `primaryLowContrast`,
  `successLowContrast` or `gray900` is translucent, the screen no longer shows through toasts and
  their message stays readable. They keep the tint those colors have elsewhere in the SDK.
- **A poll vote that fails can be cast again.** A vote tapped without a network connection left the
  poll showing the tapped option at 0% with no way to vote until the screen was rebuilt. A vote that
  is not cast now gives the options back.
- VoiceOver read a raw text key instead of the sentence of the gamification toast shown when the
  member's post gets a comment.
- **Opening a comment or a reply scrolls to it again.** A post opened on a comment — from a
  notification, a featured comment in the feed, or a profile's Comments tab — showed the top of the
  post, and a comment opened on a reply showed the top of the thread. They now land on that comment
  or reply, after loading the latest ones from the server.
- **Profile Comments tab opens the tapped comment.** Tapping a comment in a profile's Comments tab,
  or the comment a reply answers, opens the post on that comment instead of the top of the post.
  Like a featured comment in the feed, that tap no longer sends `postClicked`; tapping the post
  itself still does. The "See replies" rows of that tab now send `seeRepliesButtonClicked`, like the
  same row under a post.
- When your app was launched in the background before the device's first unlock after a reboot, the SDK
  could not read its session from the Keychain and took it for an absent one: it could treat the launch
  as a fresh install and clear the stored session, clean the user's data as after a logout, and connect
  a guest. Such a launch is no longer treated as a fresh install, and the session is kept and read
  again once the device is unlocked or the app comes back to the foreground. Until then, `connectUser`
  waits up to 5 seconds for the session, then fails with `OctopusConnectUserError.other` instead of
  connecting a guest (the fire-and-forget overload only logs it): connect the user again when your app
  comes to the foreground.
- When the nickname your app asked for was taken and the user got a variant of it, sending that variant
  back in the `ClientUser` no longer resends the nickname along with a request to find an available
  one. A new bio or picture is still synced.
- **Community switch as a guest.** After `switchCommunity` with no connected user, the rebuilt
  `OctopusHomeScreen` could show an error instead of the feed until Retry was tapped: the guest
  session of the previous community was kept and rejected by the new one. The switch now drops it,
  and the new community starts with a guest session of its own.
- `switchCommunity(apiKey:connectionMode:configuration:)` could crash the app when it was called while
  `connectUser` was still running, or while any other SDK write was in progress. A write that has not
  reached the database yet when the community switches is now dropped with an error instead: a
  `connectUser` still running then throws `OctopusConnectUserError.other`. As before, call
  `connectUser` again once the switch is done to connect the user to the new community.
- The default fonts of a theme your app created once (for instance kept in a `static let`) ignored a
  Dynamic Type text size change made while the community was displayed, and stayed at the size of the
  moment the theme was created. They now follow the text size, as they did without a theme. Fonts your
  app gives the theme are left as they are.

## 1.14.1 — 2026-10-05

### Fixed

- A crash on a Mac (iPhone and iPad apps running on Apple Silicon) when the SDK presented a sheet. The
  gamification rules sheet, which opens on its own from the third opening of the community, made the
  app crash at every opening from then on.
- A build error with the Swift 6.2 compiler (Xcode 26.2).

## 1.14.0 — 2026-09-24

### Added

- **Profile "Comments" tab.** A member's authored comments and replies, each shown with the post it
  hangs under, reusing the feed's cells. Always available on the connected user's own profile; on
  another member's profile it is gated by a per-community setting configured in the back-office.
- **"Who reacted" list.** Tapping a content's reaction summary opens a sheet listing the members who
  reacted, with one tab per reaction kind and one "All" tab.
- **Empty, loading and error states** across every list in the SDK — main feed, group list, group
  detail, post and comment detail, profile tabs, notification center — with a retry where one applies.
  A failure that happens while content is already on screen now surfaces as a toast instead of
  replacing what the member is reading.
- **Privacy manifest** (`PrivacyInfo.xcprivacy`) declaring the data the SDK collects and the
  required-reason APIs it uses. Shipped as a resource of the `Octopus` target (SPM) and of the
  `OctopusCommunity` pod (CocoaPods). Check that the App Privacy section of your app's App Store
  Connect page matches the data it declares.
- **Screen state illustrations.** `OctopusTheme.Assets.Icons.ScreenStates` and the new `screenStates`
  parameter of `OctopusTheme.Assets.Icons(...)` replace the illustrations shown on empty lists and failed
  first loads (`emptyContent`, `emptyNotifications`, `networkError`, `error`). All parameters are
  optional. Like reaction images, these illustrations keep their original colors and are not tinted.

### Changed

- The installation id now survives deleting and reinstalling the app, so a device-level ban is no
  longer shed by a reinstall. Existing installations keep the id they already have.
- When the server refuses an action on a rights basis, its own explanation is shown instead of a
  generic error message.
- Toasts: errors appear at the top of the screen, no longer stack, and the "no connection" one stays
  up until the connection is back rather than fading after a few seconds.
- Profile and Activity tab rows scroll together with their pinned counterpart, and stay readable at
  large Dynamic Type sizes and in verbose languages.
- Translations refreshed across the 24 supported languages.

### Fixed

- Links in a post or comment body were not detected once the body was truncated behind "See more".
  The text is now shortened after the markdown is parsed, so a link cut in half still points at its
  complete URL.
- A crash in `switchCommunity` when tracking was still running as its store was torn down, and a
  second one when a session heartbeat was still in flight.
- A database write landing while a screen was subscribing could be lost, leaving that screen on stale
  data until the next write came along.
- A single transient database read error permanently ended a screen's updates, leaving it empty and
  deaf to every later change.
