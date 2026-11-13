# Nationwide mobile banking: React Native

The internet banking app (`connect-banking-app/`) as a phone app, in React Native (TypeScript, bare React Native
CLI). It has Home, Accounts, every transaction with its details and a map, Cards (payments, Dispute, Your
disputes), the Money Hub, Mortgages, Help and FAQs, Notifications and Settings. Above every screen sits the same
assistant as on the web: **chat** and **call**, told which screen the customer is on, so the right assistant helps
(ARIA, the Money Hub agent, the card dispute assistant). A money alert opens its screen and **starts a chat or call
there by itself**.

The design both mobile apps follow is [`../docs/CONTRACT.md`](../docs/CONTRACT.md). This page is how this build
does it.

> **Demo.** Sample data only (James, `CUST-001`), with a banner saying so on every screen.

## Contents

- [Run it](#run-it)
- [Try push without push keys](#try-push-without-push-keys)
- [How it is built](#how-it-is-built)
- [The assistant](#the-assistant)
- [The native call module](#the-native-call-module)
- [What you add yourself](#what-you-add-yourself)
- [What still needs the web app](#what-still-needs-the-web-app)
- [Tests and what was checked](#tests-and-what-was-checked)

## Run it

You need Node 22 or later, Xcode with CocoaPods (iOS), and Android Studio with its SDK (Android). Install once:

```bash
cd /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/react_native_app
npm install
cd ios && pod install && cd ..
```

Then start Metro in one terminal, and the app in another:

```bash
cd /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/react_native_app
npm start
```

```bash
cd /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/react_native_app
npm run ios -- --simulator "iPhone 17"        # or: npm run android
```

Or open `ios/ConnectBanking.xcworkspace` (the workspace, not the `.xcodeproj`) in Xcode, pick a simulator or your
iPhone, and press Run. The first build takes several minutes.

**On an iPhone** (needed for calls and the best test of notifications): in Xcode, select the `ConnectBanking`
target › Signing & Capabilities, choose your team and a bundle identifier of your own, plug in the phone (or pair
it over Wi-Fi), enable Developer Mode on it, pick it as the destination and press Run. The phone must reach Metro on
your Mac (same Wi-Fi).

Calls need a real phone (the Amazon Chime SDK doesn't support every simulator). Local notifications work on the
simulator too.

If `pod install` says the specs repository is out of date, run `pod install --repo-update` once.

| Mode | How | What works |
|---|---|---|
| **Sample** | **Explore with sample data** on the first screen | Everything except chat and calls, from the banking app's own replies for the sample customer (`src/core/fixtures/`, made by `connect-mobile-banking/scripts/make_fixtures.py`) |

Sample mode isn't remembered: the next launch opens on sign-in. While in it, **Sign in with your link** under the
demo banner goes back to the sign-in screen. On iOS the Keychain outlives the app, so the first launch after an
install forgets any session an earlier install left there.
| **Link** | Paste the internet banking link (the one `deploy_banking_app.sh` prints) on the first screen, or open it on the phone | Everything, against the deployed banking app's own `/api/*` routes, exactly as the web app uses them |

Nothing about your account is in the app. The bank's address comes from the link when it is opened, and the link's
code is kept in the phone's secure storage (Keychain or Keystore). **Settings › Forget this device** ends any
conversation and deletes it. An expired link sends you back to the first screen.

## Try push without push keys

The app simulates push notifications with **real local notifications** (notifee). They carry exactly the data a push
would, and a tap goes through the same handler.

1. Open the app (Sample mode works for the screens; Link mode is needed for the conversation itself).
2. **More › Notifications** lists five alerts worded from your own data:

   | Alert | Starts |
   |---|---|
   | Did you make this payment? (the largest credit card payment) | a **chat**, on Cards with that payment chosen (the card dispute assistant) |
   | Your balance is getting low (the next bills) | a **call**, on Money Hub › Expected (the Money Hub agent) |
   | Your salary has arrived | a **chat**, on Money Hub › Money in |
   | Your Holiday in Japan goal | a **call**, on Money Hub › Goals |
   | A large payment left your account | a **chat**, on that payment's details |

3. Press **Send notification**. The first time, the phone asks for notification permission. The row says "Sending in
   5 seconds… lock your phone or leave the app to see it arrive."
4. Lock the phone, leave the app, or swipe it away. Then tap the notification:
   - **App open:** it shows as a banner (iOS) or a heads-up notification on the "Money alerts" channel (Android).
   - **App in the background:** the app comes forward.
   - **App closed:** the app starts and runs the alert once you're signed in.

   Each case opens the screen, waits for it to say where you are, and then starts the chat or call. A call still asks
   for the microphone first.

Tapping a row runs it at once, without a notification. In Sample mode the screen opens and the assistant says that
chat and calls need your link.

**Timing.** The notification is a notifee timestamp trigger. On iOS that uses the system's own timer, which fires
with the phone locked or the app closed. On Android it uses an inexact `AlarmManager` alarm
(`SET_AND_ALLOW_WHILE_IDLE`), which needs no exact-alarm permission and also fires with the app closed. Android can
hold it back a little in deep sleep. A JavaScript timer wasn't used, because it wouldn't survive iOS suspending the
app.

**Real push.** Firebase Cloud Messaging sits behind the same `PushSource` interface
(`src/features/notifications/data/FirebasePushSource.ts`). Without Firebase files it does nothing. A real push uses
the same `data` (CONTRACT.md section 7); a tap goes to the same handler, and a push that arrives while the app is open
is shown as a local banner.

## How it is built

Clean architecture, the same in every feature. Dependencies point inwards only: `domain` imports no React,
React Native, `fetch` or WebSocket.

```
src/
  app/                 the app shell: composition root (di.ts), session gate (App.tsx), navigation, push start-up
  core/                shared, not a feature
    config/            timings (CONTRACT.md section 13)
    network/           ApiTransport, LinkTransport (the link's secret in the body), SampleTransport (fixtures)
    fixtures/          the banking app's own replies for the sample customer, and the demo's merchant places
    format/            amounts, dates, and the assistant's message layout (a port of the web widget's format.js)
    forms/             the forms WebView's locks and bridge (pure)
    theme/  ui/  util/ colours (light and dark, from the web app's styles.css), building blocks, timers
  features/<feature>/
    domain/            entities, repository interfaces, use cases (pure TypeScript)
    data/              implementations: the API, Keychain, the Participant Service, the native call module, notifee
    presentation/      screens and components
```

| Feature | Domain highlights | Screens |
|---|---|---|
| `session` | `parseLink`, `SessionUseCases` | Sign in |
| `home` | `greeting` | Home |
| `accounts` | `Account`, `totalBalance` | Accounts |
| `transactions` | `findTransaction`, `matchCardPayment`, `lookupPlace`, `askDraft` | Transactions, Payment (with a map) |
| `cards` | `findPayment`, disputes | Cards (Payments, Your disputes) |
| `money_hub` | `HUB_VIEWS`, `validateGoal` | Money Hub (Money out, Money in, Expected, Transactions, Goals) |
| `mortgages` | `parseStartCall` (the form's bridge), `monthlyRepayment` | Mortgages |
| `help` | `FAQS` | Help and FAQs |
| `notifications` | `parseAssistIntent`, `contextMatches`, `buildSamples`, the `PushSource` and `LocalNotifier` ports | Notifications |
| `assistant` | `ChatEngine`, `CallEngine`, `PageMoveTracker`, `DisputeWatch`, `AssistantController` | Launcher, sheet, forms WebView |
| `settings` | | More, Settings |

## The assistant

One `AssistantController` for the whole app. It outlives screens, as the web widget outlives pages. Each screen
publishes its context with `useScreenContext`, and the controller never reaches into screens.

- **Chat** (`ChatEngine`) is a direct port of `web/widget/talk.js` to the Amazon Connect Participant Service
  (HTTPS and its WebSocket; not ChatJS), with rules C1 to C15. Tokens live in memory only. Going to the background
  never ends a chat; coming back rejoins it.
- **Calls** (`CallEngine`) follow V1 to V10. The microphone is asked for first; the call is joined through the native
  module; it hangs up after 25 s if the audio never connects; captions are polled every 2 s; hanging up goes through
  the Participant Service.
- **Following the customer**: page moves after 1.5 s (never the starting screen, never twice in a row), and the
  dispute watch every 4 s.
- **What it is told**: CONTRACT.md section 3. For example, Money Hub on the Expected tab is
  `{page: money_hub, view: expected}`, and Cards after **Dispute** is `{page: card_dispute, paymentId}`. Who the
  customer is never comes from the app.

## The native call module

`modules/connect-call/` is a local package, linked automatically (`"connect-call": "file:modules/connect-call"`).

| | iOS | Android |
|---|---|---|
| Code | `ios/ConnectCall.swift` (+ `ConnectCall.m` export) | `ConnectCallModule.kt`, `ConnectCallPackage.kt`, `CallService.kt` |
| SDK | CocoaPods `AmazonChimeSDK` 0.27.4 (brings `AmazonChimeSDKMedia` 0.25.4) | Maven `software.aws.chimesdk:amazon-chime-sdk` 0.25.5 and `amazon-chime-sdk-media` 0.25.4 |
| Background | `UIBackgroundModes` `audio` | A foreground service of type `microphone` |
| Microphone | `NSMicrophoneUsageDescription`, asked for by the module | `RECORD_AUDIO`, asked for from JavaScript |

It does three things: `join(meeting, attendee)`, `setMuted`, `leave`. It reports one event, `ConnectCallEvent`
(`connected`, `stopped` with the Chime status code, `muted`). Connect sends no `ExternalUserId`, so the attendee ID
stands in. The SDK versions were checked on Maven Central and CocoaPods trunk on 2 November 2026.

## What you add yourself

None of these go in the repository.

| What | Where |
|---|---|
| Google Maps key for the Android payment map | `MAPS_API_KEY=…` in `~/.gradle/gradle.properties` (iOS uses Apple Maps; no key) |
| App Links host (Android) | `APP_LINK_HOST=<app-host>` in `~/.gradle/gradle.properties` |
| Universal Links (iOS) | An Associated Domains entitlement `applinks:<app-host>` in Xcode |
| Real push | `GoogleService-Info.plist` (iOS) and `google-services.json` with the Google Services Gradle plugin (Android), plus an APNs key in Firebase. The root `.gitignore` of this folder keeps both files out |
| Signing | Your own team and keystore |

The links only open the app once the site serves `/.well-known/apple-app-site-association` and
`/.well-known/assetlinks.json` (web change W5).

## What still needs the web app

The mortgage and dispute forms are filled in through Live Sync, which exists only for the web, so they open in a
locked WebView (CONTRACT.md section 9). The WebView may load only the bank's address and the dispute pages' address;
anything else opens in the browser. The app's side of the bridge is built. The web side isn't yet
(`connect-banking-app/docs/mobile/README.md` section 6):

| # | Web change | Until it's done |
|---|---|---|
| W1 | The mortgage form listens for `mortgage:call-started` | The form's own assistant (inside the page) helps; the native launcher is hidden on the form |
| W2 | The form's **Call us** calls `AndroidBridge.startCall` inside the app | The page's own call button starts a web call |
| W3 | The app's dispute page listens for `dispute:open` `{sessionId}` | A dispute form the watch finds on a call opens on the disputes page without the form; a form posted in a chat opens from **Open the form here** (that works today) |
| W4 | A native-host mode that hides the web assistant inside the WebView | The web assistant shows inside the form |
| W5 | The `.well-known` files | Links don't open the app; paste the link instead |

## Tests and what was checked

```bash
cd /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/react_native_app
npx tsc --noEmit
npx eslint .
npx jest
```

The tests cover:

- link parsing, and the push intents (validation, topics, mode, which context to wait for);
- the five sample alerts built from the fixtures, and a tapped local notification going through the push handler;
- card payment matching, merchant places, money and date formatting, and the message layout;
- the chat rules (subscribe, heartbeat, transcript, the opener on the first assistant message or at 20 s, hidden
  return notes, the return note once per key, the dispute link, chat ended, rejoining after the background);
- the call rules (microphone first, the 25 s timeout, captions once each, colleague joined, mute, hang-up order);
- page moves (1.5 s, never the start, no repeats) and the dispute watch (once only);
- the controller's push auto-start, and a render of the whole app in Sample mode.

Checked on 2 November 2026:

| Check | Result |
|---|---|
| `npx tsc --noEmit` | No errors |
| `npx eslint .` | No errors or warnings (inline styles are allowed: they come from the theme) |
| `npx jest` | 12 suites, 92 tests, all passing |
| Metro release bundles for iOS and Android | Both built |
| `cd android && ./gradlew assembleDebug -PreactNativeArchitectures=arm64-v8a` | `BUILD SUCCESSFUL`: an APK, with the `connect-call` Kotlin module compiled against the Chime SDK |
| `cd ios && pod install` | Installed, with `AmazonChimeSDK` 0.27.4, `connect-call`, notifee and Firebase. The Podfile uses dynamic frameworks: React Native Firebase 27 brings Firebase in through Swift Package Manager and refuses static linkage |
| `xcodebuild … -sdk iphonesimulator` (Debug, iPhone 17, iOS 27.0) | `BUILD SUCCEEDED`, with the Swift call module compiled against the Chime SDK |
| The app on that simulator, with Metro | Opens on the sign-in screen |

**Not checked:**

- a real chat or call against Connect;
- the call module joining a real call on a phone;
- local notifications arriving on a phone;
- the screens past sign-in on a simulator or phone (only the Jest render of the whole app covers them).

Check these on a device before relying on them.
