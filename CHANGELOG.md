# Changelog

Notable changes to the Octopus iOS SDK, one section per version, most recent first. History for
the versions before 1.14.0 lives in the
[GitHub Releases](https://github.com/Octopus-Community/octopus-sdk-swift/releases).

## 1.16.0 — 2026-11-19

### Deprecated

- **`ClientPost.attachment` and the initializers taking an `attachment`.** Use `medias` and
  `init(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:)` instead. Both
  keep working: the initializers wrap their attachment in a one-element list, and `attachment`
  returns the first of `medias`.
- **`OctopusPrefilledPost.image` and `init(text:image:topicId:cta:sign:)`.** Use `images` and
  `init(text:images:topicId:cta:sign:)` instead. Both keep working: the initializer wraps its
  image in a one-element list, and `image` returns the first of `images`.
- **`OctopusPrefilledPost.sign`.** Read `bridgeShareTokenProvider` instead, which returns `nil`
  when the post is not signed. `sign` keeps its non-optional result and throws when the provider
  returns `nil`.
- **`OctopusProfileScreen`.** Use `OctopusHomeScreen(octopus:initialScreen: .profile(...),
  navigationMode: .navigationStack)` instead: `.navigationStack` is the navigation
  `OctopusProfileScreen` used by default. `OctopusProfileScreen` keeps working.
- `OctopusPrefilledPost.CTA(url:label:)` is deprecated: use `CTA(url:localizedLabel:)`, with
  `.autoTranslated(label)` to keep the same behaviour. The `label` property stays.
- The `ClientPost` initializers that take `viewClientObjectButtonText:` point to the one that
  takes `viewClientObjectButton:`: pass `.autoTranslated(text)` to keep the same behaviour. The
  `viewClientObjectButtonText` property stays.

### Added

- **`OctopusSDK.communityAccessDeniedReason`** tells why the user cannot access the community, as
  an `OctopusCommunityAccessDeniedReason`. It is `nil` when the access is granted or not known yet,
  and is published like `hasAccessToCommunity`. With `accountDeleted`, your app can disconnect the
  member on its side.
- **`OctopusEvent.Screen.communityAccessDenied`** is emitted when the access denied screen is
  displayed.
- **Informal tone per language.** A community can have the SDK address its members informally
  ("tu" rather than "vous", "du" rather than "Sie"…), language by language. Octopus sets it in the
  community settings; the SDK texts that address the member then use their informal version
  whenever they are displayed in one of those languages. A community that does not set it stays
  formal, and the languages with a single form (English, Swedish…) do not change.
- **Members' total points in community data.** `OctopusGamification.score`, returned by
  `fetchCommunityData(profileId:)`, `fetchCommunityData(clientUserId:)` and their
  `communityDataPublisher` counterparts, now holds the member's total points, for the connected
  member as for any other member. It was always `nil` before. Each fetch reads the total again, so
  it includes the points earned since the last fetch, including the points your app awarded. Once
  the connected member's community data has been fetched with gamification enabled, that member's
  publisher also updates when the SDK refreshes their own profile. The Octopus screens still hide
  other members' points. Other members' scores are `nil` when the server does not send the total;
  on such a server, a fetch resets the connected member's cached score to `nil` until the SDK next
  refreshes their own profile. Cached profiles get their score at their next fetch.
- **Create a client object post with several images.** `ClientPost` takes a `medias` list of up to
  10 images (`init(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:)`, and
  the `medias` property), displayed in that order. `fetchOrCreateClientObjectRelatedPost` throws
  `ClientPostError.validation` on the `file` field, without any network call, when more than 10 are
  provided. The deprecated `fetchOrCreateClientObjectRelatedPost(content:)` and
  `getOrCreateClientObjectRelatedPostId(content:)`, which take no token provider, accept a single media
  and throw the same error for more.
- **Posts with several photos.** Members can attach up to 10 photos to a post in the post
  composer. In the feed and in the post detail, a post with several photos shows them in a carousel
  swiped horizontally, with page dots below it and a "current / total" counter in its top right
  corner. A post with photos and no text now gets 8pt of space above its photos,
  instead of 4. The composer is restyled along: its photo and poll entries are two capsules, each
  an icon and its label (Liquid Glass on iOS 26), that float over the bottom of the form; the
  photos show as 220pt square thumbnails, the last one carrying an "Add" pill while more can be
  added; and the group selector is a lighter pill. The default add-picture icon (post, comment and
  reply composers) and add-poll icon are redrawn to match; a theme that sets its own icons keeps
  them.
  The photos of a post, and the local images of a bridge post created with
  `fetchOrCreateClientObjectRelatedPost(content:tokenProvider:)`, are now uploaded over HTTPS
  directly to Octopus's storage before the post is published: if your app restricts or proxies
  outbound traffic, allow it. When the server refuses a photo, the composer scrolls to it.
- **Prefill a post with several images.** `OctopusPrefilledPost` takes an `images` list of up to 10
  images (`init(text:images:topicId:cta:sign:)`, and the `images` property), which the post editor
  opens with. Empty `Data` entries are dropped, and each image goes through the same size and ratio
  checks as before, the first failing one being reported through `ValidationError`. Passing more
  than 10 images throws `OctopusPrefilledPost.TooManyImagesError`, a separate error type: a `catch`
  that only handles `ValidationError` does not cover it.
- **Close on the nickname choice screen.** The screen shown before a member's first post, comment
  or reply has a close button. Nothing is sent and no nickname is saved (unless a confirmation
  already went through): the member returns to the composer with their text kept, and the screen
  shows again on their next try.
- **Button labels per language.** The app can give the label of the button it attaches to a post in
  each of its languages, instead of letting Octopus translate it: `OctopusLocalizedText.perLanguage(
  [Locale(identifier: "en"): "Start", Locale(identifier: "fr"): "Démarrer"], defaultLanguage:
  Locale(identifier: "en"))`. A reader whose language is in the list sees that label as it is, any
  other reader an automatic translation. `OctopusLocalizedText.autoTranslated("Start")` keeps the
  automatic translation for every reader. Use it with the new
  `OctopusPrefilledPost.CTA(url:localizedLabel:)` and
  `ClientPost(clientObjectId:groupId:text:catchPhrase:medias:viewClientObjectButton:)`.
  `perLanguage` throws an `OctopusLocalizedText.ValidationError` when the labels cannot be used
  (no label, an empty label, a language without language code or the undetermined `und`, the same
  language twice, a default language that is not in the list). A label over 28 characters is
  accepted and displayed on one line, truncated. For a post linked to one of your objects, the
  labels are taken when the post is created.
- **Signed content with per-language labels.** When a button label is given per language, the
  content you sign (the `bridge_fingerprint` of a prefilled post with images, and the fingerprint
  passed to the `tokenProvider` of `fetchOrCreateClientObjectRelatedPost`) also covers
  `ctaTextLanguage`, the code of the default language, and `ctaTextTranslations`, the other labels
  by language code. Nothing changes for a label that is translated automatically: the signed
  content is the same as before. Sign the codes the SDK sends, which
  `OctopusLocalizedText.textsByLanguageCode` gives: the system rewrites some identifiers (`zh_Hant_TW`
  is sent as `zh-TW`, `sr-Cyrl` as `sr`). A language with an optional region and no script (`fr`,
  `pt-BR`, `zh-HK`) is sent as it is written.
- **Pinch to zoom on photos.** A member can pinch any photo of a post (in the feeds and on the post
  screen, a single photo or the current photo of a carousel), of a comment or of a reply, and a
  playing post video, to magnify it up to 4× around their fingers, above the screen and its bars
  with a darkening backdrop. Releasing springs it back into place; a carousel stays on its photo.
  One-finger scrolling and swiping, taps and the full-screen viewer are unchanged.
- **Optional post taps.** Two community settings, both off by default, change what a tap on a post
  opens. With `imageTapOpensPost`, tapping a post image in a feed opens the post, like tapping the
  card does, when the card opens the post detail; otherwise, and in the post detail, images still
  open full screen. With `groupNameTapOpensGroup`, tapping the group name of a post, in a feed or in
  the post detail, opens that group; a member without access to it gets the same flow as from the
  groups list (`groupAccessDeniedCallback`). `ContentOptions.PostOptions` adds the two flags, and
  its initializer takes them with `false` as default, so existing `debugOverrideContentOptions(_:)`
  calls keep compiling. Communities that do not set them keep the current navigation.
- **Profile initial screen.** `OctopusHomeScreen(octopus:initialScreen: .profile(...))` opens a
  profile directly: the connected user's own (`.currentUser`), or another member's, by your app's
  own id (`init(clientUserId:)`) or by their Octopus profile id (`init(profileId:)`). Like every
  initial screen, it shows the access denied screen when the user cannot access the community.
  When a client user id cannot be resolved, the screen shows its error state with a retry button.
- **Slovak.** The SDK is translated into Slovak (`sk`): it shows in Slovak when the app runs in
  Slovak, or when `overrideDefaultLocale(with:)` forces it.
- **Themable translation icon.** `OctopusTheme.Assets.Icons.Content.translation`, a language glyph,
  is drawn in front of the "See original" / "See translation" button of translated content.
  Override it through the new `translation` parameter of `OctopusTheme.Assets.Icons.Content.init`.

### Changed

- **A closed community no longer receives any call from the SDK.** When Octopus closes a community,
  for good or for a while, the SDK stops calling the Octopus servers until the date the server gives
  to check again. It checks then at launch or when the app comes back to the foreground, and resumes
  without a relaunch once the community reopens. While the community is closed:
  - the community screens show the closure message;
  - `hasAccessToCommunity` is `false`, `notSeenNotificationsCount` is 0, `groups` is empty and the
    community data and related posts are `nil`;
  - the functions that call the server fail with the server error they already report;
  - `connectUser` keeps the user and `disconnectUser` forgets them at once; the exchange of the
    user's token, or the connection of a guest, happens once the community reopens;
  - no analytics event is recorded, custom events included.
- **Access denied screen.** The screen displayed in place of the community when the user cannot
  access it now shows an icon, a title that depends on the reason of the refusal, and the message of
  the server under it. A banned member reads which policy they broke and who to contact, and can
  open the text of that policy. A member whose account was deleted can access the community again
  from the screen: as a member when your app has called `connectUser` since launch, otherwise as a
  guest until the next `connectUser`.
- `connectUser` and `refreshEntitlements` keep reporting a banned member with `userBanned`,
  including after a relaunch of the app.
- An access taken away while the app runs (a ban, an exclusion) is noticed as soon as the server
  refuses a call, instead of at the next launch: the screen and `communityAccessDeniedReason` follow.
- When the access is taken away while the user is on a pushed screen (a post, a profile), the
  community goes back to its root, where the access denied screen is displayed.
- When the access comes back while the access denied screen is displayed, the community replaces
  it. An `OctopusHomeScreen` presented modally used to be dismissed instead.
- **No gamification in an admin's community data.** `OctopusCommunityData.gamification` is now `nil`
  for a profile tagged admin, as when the community has gamification turned off.
- **`connectUser` reports a failure that comes after the exchange of the user's token.** Once the
  token is exchanged, the user has their Octopus account: when what follows fails, the update of
  their profile with the info passed to `connectUser` (a nickname already taken, no network), no
  guest replaces that account any more, and `connectUser` throws the error. It used to return without
  an error when the SDK could connect a guest instead.
- **Consent button before the nickname choice.** In a community with explicit terms acceptance, when
  the nickname choice screen follows the consent sheet at a member's first contribution, the sheet's
  button now reads "Accept" instead of "Accept and post", "Accept and comment" or "Accept and reply":
  the contribution is only published once the nickname is confirmed.
- **Softer default primary color in dark mode.** When the host app does not set its own primary
  color, buttons, accents and icons drawn with it now use a light gray (`#EBEBEB`) in dark mode
  instead of pure white, which glared on the dark background. Apps that pass a `primarySet` to
  `OctopusTheme.Colors` are not affected.
- **Polite form in a few texts.** Some texts addressed the member informally even in the formal
  tone; they now use the polite form: the maximum number of photos per post in Spanish, Italian
  and Portuguese, and, in Italian, the post creation placeholder and the hidden poll results.
- **New fullscreen photo viewer.** Tapping a photo of a post, a comment, a reply or a profile picture
  opens it in a new viewer: the photo flies from its place to the full screen, and back when the
  viewer closes. A member swipes between the photos of a post, zooms with a pinch or a double tap,
  and closes the viewer by dragging the photo down or with the close button, now in the top leading
  corner. A post's carousel is left on the photo the member closed the viewer on. A photo that
  cannot be loaded shows an error with a Retry button. The viewer stays dark whatever your app's
  appearance, and the screen below keeps its navigation bar.
- **Public enums open to new cases.** The SDK's public enums are now `@nonexhaustive(warn)`, so
  that a later version can add a case to them. With Xcode 26.2 or later, a `switch` that lists every
  case of one of them without an `@unknown default` gets a warning, which fails the build of a
  project treating warnings as errors. Add `@unknown default` to each such `switch`: it compiles
  without a warning on every Xcode version, and it is what keeps your `switch` compiling once a case
  is added. Enums added from now on are plain `@nonexhaustive`: in the Swift 6 language mode, a
  `switch` over one of them needs an `@unknown default` to compile. `ClientUser.AgeInformation` and
  `OctopusEvent.ProfileFieldUpdate`, which can never get a new case, stay exhaustive.
- **Post footer on one line.** Under each post, in the feeds and in the post detail, the
  reactions and comments fit on a single 44pt line: the like button with the total of reactions,
  the comment button with the number of comments, and on the right the three most used reactions,
  which open who reacted. A tap on the like button adds a ❤️ or removes the member's reaction, a
  long press still opens the reaction picker; the comment button opens the post with the comment
  field ready. Counts above 999 are shortened with the language's decimal separator ("1.2K",
  "1,2K"). The view count is removed. The "Like" and "Comment" labels are no longer shown, but
  VoiceOver still reads them. Comment and reply footers do not change.
- **A post text has no minimum length any more.** One visible character is enough, so a member can
  publish "Bravo !"; `Validators.Post.minTextLength` is now `1` (was `10`) and the 5000-character
  maximum is unchanged. A blank or whitespace-only text that the post may not omit keeps the publish
  button disabled and no longer shows "Your post must contain at least 10 characters.". An
  `OctopusPrefilledPost` accepts a short text too: `ValidationError.textTooShort` is no longer
  thrown and is kept so `switch` statements stay exhaustive.
- **A prefilled post can be sent unsigned.** The `sign` closure of `OctopusPrefilledPost` now
  returns `String?`: return `nil` when your backend cannot sign, and the post is sent without a
  token, as on Android. A community that allows member pictures publishes it with its images; one
  that forbids them refuses it and the editor shows an error. Throwing still stops the publication
  and shows an error, whatever the community setting. Existing closures returning a `String` compile
  unchanged. As before, the closure is called whenever the post carries an image, not only in
  communities that forbid pictures: only the server knows that setting for sure.
- **`OctopusProfileScreen` follows the home screen.** It now displays `OctopusHomeScreen` with the
  `.profile` initial screen, so it behaves like it: a user who cannot access the community gets
  the access denied screen, the screen keeps 16pt from the bottom edge of its window when nothing
  is below it (a device with a home button and no tab bar), and a profile that cannot be loaded
  shows an error state with a retry button instead of a bare error message.
- **A quick trip to the background no longer splits a session.** The app session, and the community
  session when the community is displayed, used to end as soon as the app went to the background and
  a new one started on return, so opening a link in another app or switching apps for a few seconds
  counted as two sessions. A return within 10 seconds now keeps the same sessions, as on Android: no
  `OctopusEvent.sessionStopped` then `sessionStarted` is emitted for it. After a longer absence, the
  sessions end at the time the app went to the background, even when the app is killed meanwhile,
  but `sessionStopped` now arrives once the 10 seconds are over, or when the app comes back if iOS
  suspended it before. To end the sessions on time, the SDK asks iOS for a few seconds of background
  execution, which needs no background mode in the app's capabilities.
- **Short timestamps.** The header of posts, comments and replies shows their age in the system's
  short format, like social apps do: "8m", "3h", "2d", "3w", then the date ("Oct 12", with the
  year when it is not the current one) from 5 weeks on. VoiceOver still reads a relative
  phrase ("8 minutes ago", "2 months ago" once the date is shown). Notifications keep their
  format.
- **No tab row for a single tab.** When the community does not share its members' comments,
  another member's profile shows their posts right under the profile header, with no "Posts" tab
  row above them and no pinned tabs on scroll, as their Activity screen already did. A profile
  with several tabs, including the connected user's own, keeps its tab row.
- **Translation toggle above the content.** On an automatically translated post, comment or reply,
  the "See original" / "See translation" button now sits right under the author, before the
  content, with a language icon in front of its label. It is drawn in `gray500`, like the date,
  instead of `gray700`, and its label stays on one line.

### Fixed

- **Banned device.** On a device where a banned account was used, a guest, or another member who
  signs in, is shown the access denied screen of that ban instead of an alert. Once the account is
  no longer banned, the SDK leaves that screen by itself with a new session: as a guest, or for a
  member, with the exchange of their token once your app has called `connectUser` in this launch,
  which then no longer reports the ban. Nothing is shown in between: `hasAccessToCommunity` and
  `communityAccessDeniedReason` keep the ban until the access of the new session is read.
- **Replies of a comment listed from the first one.** Opening a comment on its first replies no
  longer shows its most recent ones first, nor below the first pages while the next one loads: the
  screen shows its loader until the first replies are known, then adds the most recent ones once
  the pages reach the end of the thread.
- **No more endless community access checks after a failure.** When the check of whether the user
  can access the community failed, the SDK retried it 5 seconds later, then 10, 15 and so on, for as
  long as the app ran. It now retries twice, 5 and 10 seconds later, then checks again only once the
  app comes back to the foreground or the network comes back. In the meantime it keeps the last
  access it knew. With none (first launch, or after the user changed), `hasAccessToCommunity` stays
  `false` until a check succeeds, while the community screens still open: they only show the
  access denied screen once the server has answered that the user cannot access the community.
- **No more endless community configuration fetches after a failure.** When fetching the community
  configuration failed, the SDK retried it 5 seconds later, then 10, 15 and so on, for as long as the
  app ran, and stopped for good when a retry found no network. It now retries twice, 5 and 10 seconds
  later, then fetches again once the app comes back to the foreground or the network comes back.
- **Comment and reply composer stuck after a failed first send.** When recording a member's
  acceptance of the terms failed at their first comment or reply (network lost, server error), the
  composer stayed disabled after the error alert until the screen was left. It is enabled again.
- **Content menu colors.** The delete action of a post, comment or reply menu shows in red, like
  Report and Block. The icons of the other menu actions (View group on a post, the actions of
  another member's activity menu) keep the color of their title instead of taking the host app's
  tint or the theme's primary color.
- When your app was launched in the background before the device's first unlock after a reboot, the SDK
  could not open its database files and took them for broken ones: it deleted them, losing the cached
  content and the analytics events not sent yet, and could run without a database until the next launch.
  The files are now kept and the database is loaded once the device is unlocked or the app comes back
  to the foreground, the cached content showing up then.
- **Loading indicator stuck at the bottom of a list.** When the next page of posts, comments or
  replies only held items already shown (the list changed while scrolling, or an earlier load
  failed halfway), scrolling down showed the loading indicator without adding anything until it
  was scrolled away and back. The page after it is now loaded at once.
- **Content skipped while scrolling a list.** When a feed of posts, comments or replies changed
  while a member scrolled it, an item of the next page could be left out. Every item now shows
  once, in its place.
- **List ending after a failed load.** A failed load of the next posts, comments or replies while
  scrolling (network lost, server error) made the list look complete until it was refreshed. The
  next items are now asked for again on the next scroll.
- Fixed a rare crash when a feed of posts, comments or replies was released while its content was
  being updated.
- **Group page of a hidden group.** A member who may not see a group in the groups list, but may
  access it, now opens its page (from a link or a notification) instead of a "content not
  available" message. Such a group is still left out of the groups list, and its page does not
  offer to follow it.
- **Image loading off the main thread.** An image missing from the cache no longer starts its
  download from a background queue, which could race with the view releasing it while scrolling,
  and image downloads share one URL session instead of leaking one session per image.
- **Logout.** Cached posts, comments, replies and groups, including their access permissions,
  are cleared when the user logs out or another user connects, so they cannot be reused by the
  next session. The screens on display (post feeds, including a member's profile, a post, a
  comment, a group) load their content again instead of reading the cleanup as deleted content:
  a post or a comment shows a loader while it is checked again, an error with a retry when the
  check fails or the device is offline, and "not available" only when the server says it is gone
  or out of reach.
- **Refreshing a long thread.** Refreshing a post or a comment on which the member loaded many older
  responses now fetches the responses it lacks 100 at a time, instead of in a single server call
  whose response grew with the thread.
- **Long threads stay smooth as the member scrolls up.** On a post or a comment opened on its most
  recent responses, the older pages loaded as the member scrolls up are now laid out only as they
  come on screen, instead of all at once. A member reading older responses is no longer brought
  back to the bottom when a new one arrives.
- **Row spacing on iOS 13.** Lists of posts and comments no longer add a default spacing between
  their rows, matching iOS 14 and later.
- **Main feed after a sign-in.** When a guest signs in as a member, the community's main feeds are
  loaded again for the member: the "Followed" feed no longer stays the guest's until the next
  launch.
- **Bold and italic kept on links and in the legal notice.** In the community's consent wordings
  and in post, comment and reply bodies, a link written in bold or italic, or whose label is, now
  shows that emphasis instead of an upright, regular link; and from iOS 15, the bold of the
  implicit legal notice under the composers is now visibly bold. On iOS 13 and 14, a link inside
  bold or italic text is also kept as a link, and underscores inside a word or a URL
  (`my_file`, `?utm_source=…`) no longer turn into italic or cut a link short.
- **No guest account for a user who cannot access the community.** When the community is closed to a
  user, an A/B test for instance, `connectUser` used to answer the profile update the server refuses
  them by connecting a guest instead, a new guest account on each launch, which skewed the count of
  accounts. The user now stays connected with their own account, and `connectUser` throws
  `OctopusConnectUserError.communityAccessDenied` instead of `server(_)`, or of returning on a guest
  session. Once the community opens to them, their profile gets the info passed to `connectUser`,
  which it could miss when the community had been open on a previous launch.
- **"Write a post" button missing after a logout.** Right after `disconnectUser`, the groups loaded
  before the guest session was there could be stored after the guest's own: the guest was then
  allowed to post in no group, and the "Write a post" button stayed hidden until the groups were
  loaded again. Groups loaded for a session that ended before they were stored are now loaded
  again for the current one.
- **Comments of a post listed from the first one.** Opening a post on its first comments no longer
  shows its most recent ones first, nor below the first pages while the next one loads: the screen
  shows its loader until the first comments are known, then adds the most recent ones once the
  pages reach the end of the thread.
- **Long threads open fast.** Opening a post or a comment on its most recent responses (through
  the comments count or the comment button of a feed) and sending a response no longer load and
  lay out every response of the thread: the screen lists the 20 most recent ones and loads older
  ones, 50 at a time, as the member scrolls up.
- **A post opened on a comment stays smooth.** Opening a post on a comment (from a notification, or
  from the comments of a profile) no longer lays out every comment loaded around it at once: the
  pages loaded above and below the comment are laid out only as they come on screen, so scrolling
  through them no longer stutters and loading a page no longer freezes the screen.
- **A post opens fast on one of its comments.** Opening a post on a given comment (from a
  notification, a featured comment in a feed or a profile) no longer loads every comment between
  the most recent one and that comment: the screen lists the comments around it, then loads more
  recent ones as the member scrolls down and older ones as they scroll up. While the screen shows
  that window, the comments listed are no longer reloaded every few seconds, so none of them
  disappears.
- **Reactions bar inside the safe area.** On a device whose camera sits on a side edge, like the
  foldable iPhone, the reactions bar opened by a long press on Like was centered on the whole
  window, so it sat off-center and ran under the camera. It is now centered on, and sized to, the
  window's safe area, and follows it when the device is rotated or the window resized.
- **No error screen when the community opens while the user is being connected.** Opening the
  community right after `switchCommunity` and the `connectUser` that follows it could show "Oops,
  an error occurred" until Retry, then the feed of a signed-out visitor with no group names. The
  feeds, groups, posts, comments, reactions and profiles that were loading while the session changed
  are now loaded again with the new session, and so are the feeds and groups loaded before any
  session was there, after a community switch or a logout.
- **Reports for illegal activities or products.** A content or a profile reported for "Illegal
  activities or products" reaches moderation with that reason instead of being filed as spam. The
  reason keeps its `fakeProfilesAndImpersonation` case name in `OctopusEvent.ReportReason`.

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
