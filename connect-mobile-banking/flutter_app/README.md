# Nationwide mobile banking (Flutter)

A mobile banking app with the same assistant as the internet banking web app (`connect-banking-app/`). Chat or call
from any screen, and the assistant knows which screen you're on and what you're looking at. A notification about
your money can open the right screen and start a chat or a call there.

It's built against [`../docs/CONTRACT.md`](../docs/CONTRACT.md), which it shares with the React Native app in
`../react_native_app/`. Where this page and the contract differ, the contract is right.

> **Demo.** Sample data only (James, a fictional customer). There is no username or password: the internet banking
> link stands for James signed in, as on the web.

## Contents

- [What it does](#what-it-does)
- [Run it](#run-it)
- [Try push without push keys](#try-push-without-push-keys)
- [How it's built](#how-its-built)
- [Calls: the native plugin](#calls-the-native-plugin)
- [Real push notifications](#real-push-notifications)
- [What's verified, and what isn't](#whats-verified-and-what-isnt)
- [What the forms still need](#what-the-forms-still-need)

## What it does

| Screen | What's on it | What the assistant is told |
|---|---|---|
| Home | Greeting, accounts, shortcuts, latest payments | `home` |
| Accounts | Current account and saver, their movements, the mortgage | `accounts` |
| Transactions, and each transaction | Search, money in or out, 25 at a time. Each transaction shows its details, category (which you can change), and where it happened on a map | `money_hub`, `transactions`. A transaction also offers words for the chat box |
| Cards | Your cards, their payments with **Dispute**, and **Your disputes** | `cards`, or `card_dispute` with the payment chosen |
| Money Hub | Five tabs: Money out, Money in, Expected, Transactions, Goals (add and delete goals) | `money_hub` and the tab |
| Mortgages | Products, and the application form (the web page, in a WebView) | `mortgages` |
| Help and FAQs | The web app's questions and a few more; your disputes | `help` |
| Notifications | Sample alerts that open a chat or a call | `home` |
| Settings | This phone's sign-in; Forget this device | `home` |

**The assistant** is a bottom sheet over every screen, opened from the launcher above the tab bar. It does
everything the web widget does (`connect-banking-app/web/widget/talk.js`):

- the server's opener once ARIA is listening;
- return notes when a specialist hands back;
- "Open the form here" for the dispute form's link;
- captions on calls, and "A colleague has joined the call.";
- 25 seconds to connect.

While a conversation goes on, it follows you. A screen you stay on for 1.5 seconds is told to the assistant
(`contact/page`). Every 4 seconds it checks whether the dispute assistant has sent its form. Minimise the sheet and
the conversation carries on; × ends it. A chat survives the app going to the background, and a call keeps going
there. On a form (where the launcher is hidden), a thin bar says "On a call with us" or "In a chat with us", with
**Open**.

## Run it

You need Flutter 3.47 or later, with Xcode for iOS or the Android SDK for Android.

```bash
cd /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/flutter_app
flutter pub get
flutter run
```

On iOS, the first build installs the pods (the Amazon Chime SDK among them). For calls and notifications, use a
real phone: simulators have no reliable microphone path, and the Chime SDK doesn't support some emulators.

**Sample mode.** On the sign-in screen, choose **Explore with sample data**. Every screen works from the bundled
fixtures (`assets/fixtures/`, the banking app's own replies, made by
`/Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/scripts/make_fixtures.py`). Changes
you make (categories, goals) last until the app closes. Chat and calls need the link.

Sample mode isn't remembered: the next launch opens on sign-in. While in it, **Sign in with your link** in the
demo banner goes back to the sign-in screen. On iOS the Keychain outlives the app, so the first launch after an
install forgets any session an earlier install left there (the mark is kept in `shared_preferences`).

**Link mode.** You need a link from the deployed banking app. `deploy_banking_app.sh` prints one; it looks like
`https://<app-host>/#k=<secret>`. Paste it on the sign-in screen. The app then calls that backend's own `/api/*`
routes, with the secret in each request, exactly as the web app does. No backend change is needed.

- The link's host comes from the link. Nothing in the app names a host, account or instance.
- The link is kept in the phone's secure storage (Keychain or Keystore).
- When it expires, the app goes back to sign-in.

After the fixtures change, copy them in again:

```bash
cp /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/fixtures/*.json \
   /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/flutter_app/assets/fixtures/
```

## Try push without push keys

Go to **More › Notifications**. There are five sample alerts, worded from your own data, each with a fixed mode:

| Alert | Opens |
|---|---|
| Did you make this payment? (the largest credit card payment) | Cards with that payment chosen, then a **chat** with the dispute assistant through ARIA |
| Your balance is getting low | Money Hub › Expected, then a **call** |
| Your salary has arrived | Money Hub › Money in, then a **chat** |
| Your Holiday in Japan goal | Money Hub › Goals, then a **call** |
| A large payment left your account | That transaction's details, then a **chat** |

- **Send notification** shows a real notification from the phone 5 seconds later, so you have time to lock the
  phone or leave the app. On Android it arrives on the "Money alerts" channel; on iOS as a banner.
- Tap the notification and the app goes to the screen and starts the conversation. A call still asks for the
  microphone first. This works with the app open, in the background, or closed: a closed app reads the notification
  that launched it and runs it once sign-in has loaded.
- Tapping the row itself does the same at once, without a notification.
- The conversation starts only once the screen says what the alert asked for (the right tab, or the payment chosen
  on Cards), so an already-open screen never starts it with its old tab. If that never comes, it starts after
  6 seconds anyway.

A local notification carries exactly the `data` a real push would. It goes through the same handler
(`lib/features/notifications/presentation/intent_runner.dart`), so what you see here is what a real push does.

The first **Send notification** asks for permission. If you refuse, the row says "Allow notifications for this
app in Settings to try this."

In Sample mode the screen still opens, but the assistant explains that chat and calls need the link.

## How it's built

Clean architecture, one folder per feature, three layers each. Dependencies point inwards only:

```
lib/
  main.dart, app.dart            start-up; app-wide wiring (notifications, background and foreground)
  core/
    config/                      the web app's timings (contract section 13)
    di/                          the session, the transport that follows it, the data version
    network/                     ApiTransport, LinkTransport (/api with the link), SampleTransport (fixtures)
    routing/                     go_router: five tabs, each with its own stack; opening the forms
    theme/                       the web app's colours, light and dark
    format/                      £ amounts and dates as the web app writes them
    webview/                     the locked forms WebView
    widgets/                     shared pieces (payment rows, cards, loading and error states)
  features/<feature>/
    domain/                      entities, repository interfaces, rules. No Flutter, no HTTP
    data/                        JSON → entities, transports, the Participant Service, native calls, push
    presentation/                screens, widgets, providers (Riverpod)
```

| Feature | Domain highlights |
|---|---|
| `assistant` | `ChatSession` and `CallSession` (talk.js ported, every port injected), `PageMover`, `DisputeWatch`, the form bridge |
| `notifications` | `parseAssistIntent` (validation and the topic table), `sampleNotifications`, the `PushSource` and `LocalNotifier` ports |
| `transactions` | `placeFor` (the map), `cardPaymentIdFor` / `disputablePaymentId` (Dispute this payment), `findTransaction` |
| `session` | `parseLink` (https only, a well-formed secret) |
| `money_hub`, `cards`, `accounts`, `home`, `mortgages`, `help` | entities and repositories |

Screens never reach into the assistant. Each wraps itself in `ScreenContextScope` with what it would tell the
assistant. The router says which screen is showing, and the assistant reads `ScreenContexts.current` when it needs
to know.

## Calls: the native plugin

Calls use the Amazon Chime SDK through a small platform channel. Dart owns the sequence; the native side only
joins, mutes and leaves.

| | iOS | Android |
|---|---|---|
| Code | `ios/Runner/ConnectCallPlugin.swift` (registered in `AppDelegate.swift`) | `android/app/src/main/kotlin/.../ConnectCallPlugin.kt` (registered in `MainActivity.kt`) and `CallService.kt` |
| SDK | Pods `AmazonChimeSDK` 0.27.4 and `AmazonChimeSDKMedia` 0.25.4 | Maven `software.aws.chimesdk:amazon-chime-sdk` 0.25.5 and `amazon-chime-sdk-media` 0.25.4 |
| Background | `UIBackgroundModes` `audio` | a foreground service of type `microphone` |
| Microphone | `NSMicrophoneUsageDescription`; `PERMISSION_MICROPHONE=1` for permission_handler (Podfile) | `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` |

Channel `connect_call`:

- **methods:** `join({meeting, attendee})`, `setMuted({muted})`, `leave()`;
- **events** (`connect_call/events`): `connected`, `stopped` (with the Chime status code), `error`.

`meeting` and `attendee` are `StartWebRTCContact`'s `ConnectionData`. Connect sends no `ExternalUserId`, so the
`AttendeeId` stands in for it. Hanging up tells Connect first (the Participant Service's `disconnect`) and then
leaves the meeting.

## Real push notifications

`lib/features/notifications/data/firebase_push_source.dart` is ready behind the same `PushSource` interface. It
stays silent until you add your own Firebase project. Nothing for it is in the repository, and nothing should be.

1. Create a Firebase project with an iOS app and an Android app (bundle `com.example.connectbanking.connect_banking`,
   or your own).
2. Run `flutterfire configure`, or add `GoogleService-Info.plist` (iOS) and `google-services.json` (Android)
   yourself. The folder's `.gitignore` keeps both out of git.
3. For iOS, upload an APNs key to Firebase and enable Push Notifications in the Runner target's capabilities.
4. Your push backend sends `data` exactly as in contract section 7 (`v`, `intent`, `topic`, `mode`, `paymentId` or
   `transactionId`). It never sends a secret, a customer ID or an amount the app should trust.

A push that arrives while the app is open is shown again as a local notification banner, so its tap goes through
the same handler. The device token goes to your push backend, which this demo doesn't have.

## What's verified, and what isn't

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 54 tests pass. They cover the link, push intents and the topic table, the sample notifications from the fixtures, waiting for the screen's context before a notification starts the conversation, card payment matching, places, formatting, chat rules C1 to C13, call rules V1 to V9, page moves, the dispute watch, the form bridge, and the app booting in Sample mode with notification taps reaching the right screen |
| `flutter build apk --debug` | Builds (the Kotlin Chime plugin compiles against the SDK) |
| `flutter build ios --no-codesign --debug` | Builds (the Swift Chime plugin compiles against the pods) |
| Chime plugin APIs | Written against the SDKs' own sources (Android 0.25.5 sources jar; iOS v0.27.4 on GitHub) |
| Not run | A real chat or call against Connect; the app on a real phone or simulator; local notifications arriving on a device; real push |

## What the forms still need

The mortgage and dispute forms are filled in through Live Sync, which only exists for the web, so they stay web
pages in a WebView locked to the bank's own origins. The app's side of the bridge is written. The web side
(`connect-banking-app/docs/mobile/README.md`, section 6) isn't wired yet:

| # | Web change | Until then |
|---|---|---|
| W1 | The mortgage form listens for `mortgage:call-started` and binds Live Sync to that contact | The form's own assistant (inside the WebView) helps with the form |
| W2 | The form's **Call us** calls `AndroidBridge.startCall` (the app's shim) inside the app | The form starts its own call |
| W3 | The dispute page opens the form on `dispute:open` with `sessionId` | A form the dispute watch opens shows the disputes list; the chat's own link opens the form directly |
| W4 | `?host=native` hides the web assistant inside the app | The web's assistant shows inside the WebView too |
| W5 | `/.well-known` files for Universal Links and App Links | Paste the link on the sign-in screen; opening it from another app doesn't open this one |
