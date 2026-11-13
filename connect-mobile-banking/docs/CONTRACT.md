# The mobile apps' contract

The Flutter app and the React Native app are two builds of **one** design. This page is what both follow: the
backend they call, what each screen tells the assistant, how chat, calls and shared forms behave, how a push
notification opens the assistant, and the code layout. When the two apps disagree, this page is right.

The reference is the internet banking web app, `connect-banking-app/`. Its behaviour is the spec. Where this page
names a rule, the rule's source is in brackets, such as `[talk.js]` or `[journeys.py]`.

## Contents

1. [Modes and sign-in](#1-modes-and-sign-in)
2. [The backend routes](#2-the-backend-routes)
3. [Screens and what each tells the assistant](#3-screens-and-what-each-tells-the-assistant)
4. [The assistant: chat](#4-the-assistant-chat)
5. [The assistant: calls](#5-the-assistant-calls)
6. [Following the customer: page moves and dispute forms](#6-following-the-customer-page-moves-and-dispute-forms)
7. [Push notifications that open the assistant](#7-push-notifications-that-open-the-assistant)
8. [Transaction details and the map](#8-transaction-details-and-the-map)
9. [Shared forms in a WebView](#9-shared-forms-in-a-webview)
10. [Architecture](#10-architecture)
11. [Look and feel](#11-look-and-feel)
12. [Security rules](#12-security-rules)
13. [Constants](#13-constants)

## 1. Modes and sign-in

| Mode | How it starts | Data | Assistant |
|---|---|---|---|
| **Sample** | "Explore with sample data" on the sign-in screen | `fixtures/*.json`, bundled in the app (the banking app's own replies for the sample customer, made by `scripts/make_fixtures.py`) | Off: `talk` is `false`, as the web app hides its assistant when chat isn't set up. The launcher explains that chat and calls need the internet banking link |
| **Link** | The customer opens the app from their internet banking link | The deployed banking app's own `/api/*` routes | On, exactly as on the web |

**The link.** The demo has no username or password: the link stands for the customer signed in (see the banking
app's README). It looks like `https://<app-host>/<any path>#k=<secret>`.

- Parse it once: the **origin** (`https://<app-host>`) is the API base and the WebView's allowed origin; the
  part after `#k=` is the **session secret**. The secret must match `^[A-Za-z0-9_-]{16,128}$`. Refuse anything that
  isn't `https`.
- The customer gives the link by pasting it, or by opening it on the phone (a verified Universal Link or App
  Link; see S7 in `connect-banking-app/docs/mobile/README.md`, which needs web change W5). Never a custom URL scheme.
- Keep `{origin, secret}` in the platform's secure store (Keychain or Keystore), never in plain preferences. The
  web app keeps it in `localStorage` for 24 hours; the secure store is the mobile equivalent.
- **"Forget this device"** in Settings ends any conversation and deletes both.
- Any reply `403` with `error: "link_expired"` means the link has expired: forget it and go back to sign-in, with
  the message "That link no longer works. Open your internet banking from a new link." `[app.js whenExpired]`

**Later: a proper sign-in.** `connect-banking-app/docs/mobile/README.md` (B1 to B9) describes a `/mobile/v1/*`
front door with the bank's own sign-in (OIDC) and a JWT. Nothing of it is built. Both apps keep the transport
behind one interface (`ApiTransport`: `post(route, body) → json`), so moving to it is a new transport that sends
`Authorization: Bearer` to `/mobile/v1/<route>` in place of the secret in the body. No screen changes.

## 2. The backend routes

Every call is `POST <origin>/api/<route>`, JSON in and out, with `token` (the session secret) added to the body by
the transport. Nothing else names the customer. `[banking_api.py web]`

| Route | Body (besides `token`) | Reply (the fields the apps use) |
|---|---|---|
| `app/home` | | `firstName`, `asOf`, `accounts[]`, `recent[]`, `cards[]`, `talk`, `verified`, `disputePagesUrl` |
| `app/accounts` | `account`: `current` or `savings` | `asOf`, `accounts[]`, `selected`, `recent[]` |
| `app/cards` | | `cards[]` (`type`, `ending`, `name`), `payments[]` (`id`, `date`, `merchant`, `amount` (positive), `card`, `ending`) |
| `hub` | | `overview`, `forecast`, `monthlySpending`, `monthlyIncome`, `recurring`, `discretionary`, `goals`, `choices`, `talk` |
| `transactions` | `from`, `to` (`YYYY-MM-DD`), `category`, `direction` (`in`, `out`), `merchant`, `page` | `transactions[]` (`transactionId`, `date`, `merchant`, `merchantName`, `amount` (negative = out), `category`, `categoryWords`, `direction`, `balanceAfter`, `recategorised`), `page`, `totalPages`, `total`, `hasMore` (25 a page) |
| `recategorise` | `transactionId`, `category` | `transaction` |
| `goal` | `name`, `target`, `byDate`, `saved` | `goal`, `plan` |
| `goal/delete` | `name` | `goals` |
| `disputes` | | `disputes[]` (`disputeId`, `status`, `statusWords`, `merchant`, `amount` (string), `transactionDate`, `cardType`, `cardLastFour`, `missing[]`, `open`, `canSubmit`, `transactionId`) |
| `disputes/submit` | `disputeId` | `dispute` (only from a verified link; else `403 not_verified`) |
| `mortgage/config` | | `products[]` (`id`, `name`, `rate`, `fee`, `maxLtv`, `fixedTermYears`) |
| `contact/chat` | `page`, `view`, `stage`, `applicationId`, `paymentId` | `contactId`, `participantToken`, `region`, `verified`, `journey`, `opener` |
| `contact/call` | the same | `contactId`, `participantToken`, `meeting`, `attendee`, `region`, `verified`, `transcript`, `journey` |
| `contact/transcript` | `contactId` | `lines[]` (`at`, `who`, `text`), `ended`, `withPerson`, `unavailable` |
| `contact/returned` | `contactId` | `note`, `key` |
| `contact/page` | `contactId`, `page`, `view`, `stage`, `applicationId`, `paymentId` | `page`, `ariaTold` |
| `disputes/live` | `contactId` | `dispute`, `formSent` |
| `disputes/open` | `contactId`, `disputeId` | `sessionId` |

Errors come back as `{error, message}` with a 4xx or 5xx status. Show `message` (it's written for customers).

The reply shapes are exactly those in `fixtures/` (made from the backend's own code), so the Sample mode transport
and the Link mode transport return the same thing. Sample mode answers the write routes (`recategorise`, `goal`,
`goal/delete`, `disputes/submit`) in memory for the session.

## 3. Screens and what each tells the assistant

Each screen publishes a **screen context**. Only these fields go to the server; who the customer is never does.
`[talk.js pageFields]`

```
ScreenContext { page, view?, stage?, applicationId?, paymentId?,   // sent to the server
                label, launcher, draft? }                          // shown in the app only
```

| Screen | `page` | Other fields | `launcher` (the button's words) |
|---|---|---|---|
| Home | `home` | | Ask us anything |
| Accounts (current, savings) | `accounts` | | Ask us anything |
| Transactions list | `money_hub` | `view: transactions` | Ask about your money |
| Transaction details | `money_hub` | `view: transactions`; `draft` (see 8) | Ask about this payment |
| Cards › Payments | `cards` | | Help with a payment |
| Cards, after **Dispute** on a payment | `card_dispute` | `paymentId` | Help with a payment |
| Cards › Your disputes | `cards` | | Help with a payment |
| Money Hub, each tab | `money_hub` | `view`: `out`, `in`, `expected`, `transactions`, `goals` | Ask about your money |
| Mortgages | `mortgages` | | Help with a mortgage |
| Mortgage application (WebView) | none: the native launcher is hidden; the form's own assistant helps (see 9) | | |
| Help and FAQs | `help` | | Ask us anything |
| Notifications, Settings, More | `home` | | Ask us anything |

Why the native Mortgages screen sends `mortgages` and not `mortgage`: the server's `mortgage` journey needs the
form's own `applicationId` and `stage`, which live in the form page (in the WebView), not in the app. `mortgages`
is one of the server's own pages (`journeys.MOVED_TO`): ARIA helps with mortgages, and the form's own assistant fills
the form.

What the server does with each is `connect-banking-app/bankapp/journeys.py`: `money_hub` reaches the Money Hub
agent through ARIA, `card_dispute` reaches the card dispute assistant through ARIA with that payment, and everything
else reaches ARIA. A chat's first message (`opener`) comes from the server, worded for the page.

**`draft`.** A screen may offer words for the chat box, such as "About my £32.45 payment to Amazon on 15 October: ".
The app puts them in the input, unsent; the customer can change or delete them. It is the customer's own message
only if they send it. The server's `opener` stays the only thing sent automatically.

## 4. The assistant: chat

A port of `connect-banking-app/web/widget/talk.js`. The Participant Service base is
`https://participant.connect.<region>.amazonaws.com/participant`, with `<region>` from the start reply. Every call
is `POST <base>/<path>` with header `X-Amz-Bearer: <token>` and a JSON body.

| # | Rule | Source |
|---|---|---|
| C1 | `contact/chat` with the screen's fields. Keep `contactId`, `participantToken`, `opener`, `journey`, `region` in memory only | `startChat` |
| C2 | `connection` with the participant token and `{"Type": ["WEBSOCKET", "CONNECTION_CREDENTIALS"]}` (never `ConnectParticipant`). Keep `ConnectionCredentials.ConnectionToken` in memory; open `Websocket.Url` | `startChat` |
| C3 | On open: send `{"topic":"aws/subscribe","content":{"topics":["aws/chat"]}}`; then `{"topic":"aws/heartbeat"}` every 10 s | `startChat` |
| C4 | Then `transcript` with the connection token and `{"MaxResults":100,"ScanDirection":"BACKWARD","SortOrder":"ASCENDING"}`; handle each item as if it came on the socket | `startChat` |
| C5 | Socket frames: only `topic == "aws/chat"`; `content` is a JSON string of one item. Skip items whose `Id` was seen | `onChatItem` |
| C6 | `MESSAGE`: never show a customer message starting `Back from card dispute:` or `Back from mortgage application:`. Show non-blank messages: the customer as **You**, everyone else as **Assistant** (one voice, whichever assistant is helping). Markdown `**bold**` shows as plain text | `onChatItem`, `show` |
| C7 | The input stays disabled until the opener has been handled. On the **first non-customer message** (blank or not) send the opener once (if the server gave one) with `{"ContentType":"text/plain","Content":<opener>,"ClientToken":<uuid>}`, then enable the input. If no such message arrives within 20 s of the socket opening, do it anyway | `sendOpener` |
| C8 | After the opener: a **blank** non-customer message means ARIA's bot block started again. Call `contact/returned`; if it returns a `note` whose `key` differs from the last one sent, send the note as a message. One request at a time | `sendReturnNote` |
| C9 | An assistant message containing `disputePagesUrl` (from `app/home`) followed by `#k=<16 to 128 of A-Za-z0-9_->` gets a button **Open the form here**, which opens that exact link in the forms WebView (9) | `disputeToken` |
| C10 | `EVENT` with `ContentType` `application/vnd.amazonaws.connect.event.chat.ended`, or the socket closing while the app is in the foreground: the chat has ended | `onChatItem` |
| C11 | Sending: `message` with `{"ContentType":"text/plain","Content":<words>,"ClientToken":<uuid>}` | `sendChat` |
| C12 | Ending: `disconnect` with the connection token and `{"ClientToken":<uuid>}`, then clean up | `hangUp` |
| C13 | **Mobile only.** Going to the background never ends a chat. On return to the foreground, if the socket has closed but the chat hasn't ended, call `connection` again with the same participant token, reopen the socket (C3) and fetch the transcript (C4); seen `Id`s stop repeats | new |
| C14 | A finished conversation clears the log and leaves one status line saying how it ended (for example "The chat has ended.") | `finish` |
| C15 | Every assistant message refreshes the current screen's data (the assistant may have saved a goal or moved a payment to another category); so does the end of a conversation | `onActivity`, `onEnded` |

Status lines, in order: "Connecting you…", "Connecting you to our assistant…", "Connected.". Use the web's words.

## 5. The assistant: calls

Audio only, through the Amazon Chime SDK for iOS and Android, behind one small native interface (a Flutter
platform channel; a React Native native module). Dart or TypeScript owns the sequence; the native side only joins,
mutes and leaves.

| # | Rule | Source |
|---|---|---|
| V1 | Ask for the microphone **first**, so a refusal costs nothing. Refused: "To call, allow this app to use your microphone." | `startCall` |
| V2 | `contact/call` with the screen's fields | `startCall` |
| V3 | Join with the reply's `meeting` and `attendee`. The native side builds the Chime configuration from them: `MeetingId`, `MediaRegion`, `MediaPlacement.AudioHostUrl`, `AudioFallbackUrl`, `SignalingUrl`, `TurnControlUrl`; `AttendeeId`, `JoinToken`; Connect sends no `ExternalUserId`, so use the `AttendeeId`. Echo cancellation and noise suppression on (the platform's voice-chat audio mode) | `startCall`; `connect-banking-app/docs/mobile/native-ios-android.md` |
| V4 | Native events up to Dart/TS: `connected`, `stopped` (with the Chime status code), `muted`, `error`. Nothing else crosses | new |
| V5 | If not `connected` within 25 s: hang up (V8) with "The call couldn't connect. A VPN or work network can block calls: try another network, or use Chat." | `CONNECT_WAIT_MS` |
| V6 | When `transcript` is true, poll `contact/transcript` every 2 s, one request at a time. Show each new line once (key `at|who|text`), `who == "customer"` as **You**. `unavailable` stops polling. `withPerson` turning true: "A colleague has joined the call." | `readTranscript` |
| V7 | Mute and unmute; the button's words follow (**Mute**, **Unmute**) | `toggleMute` |
| V8 | Hanging up: `connection` with the participant token and `{"Type":["CONNECTION_CREDENTIALS"]}`, then `disconnect` with that connection token, then leave the Chime meeting. Status "You ended the call." | `hangUp` |
| V9 | `stopped` after connecting: "The call has ended." Before: the V5 words | `audioVideoDidStop` |
| V10 | **Mobile only.** A call carries on in the background (iOS background mode `audio`; an Android foreground service of type `microphone`) | new |

The face on video (Tavus) isn't in the mobile apps.

## 6. Following the customer: page moves and dispute forms

From `connect-banking-app/web/app.js`.

**Page moves.** During a conversation, when the screen context changes (any field in
`page|view|stage|applicationId|paymentId`) and stays the same for 1.5 s, call `contact/page` with the new fields.
Never report the context the conversation started on; never report the same one twice in a row. Errors are ignored
(the next move tries again). This is what lets ARIA bring in the Money Hub agent after the customer moves to the
Money Hub mid-chat. `[pageMoved]`

**The dispute watch.** During any conversation, every 4 s: `disputes/live`. When `formSent` is true and there's a
`dispute`, once per conversation: `disputes/open` with its `disputeId`, which gives a `sessionId`, then open the
dispute form (9) and say "Your dispute is open on the Cards screen, under Your disputes. Watch it fill in as you
talk." Opening the form from the chat's own link (C9) also counts as the once. `[watchDisputes]`

**Starting on Cards with a payment chosen** (`card_dispute`) is how the customer reaches the dispute assistant
directly; **Dispute** on a payment chooses it and opens the assistant, as the web does.

## 7. Push notifications that open the assistant

A notification about money (a payment, money coming in or going out, a low balance, a bill, a savings goal)
opens the right screen and starts a chat or call there, so the right assistant has the right context from the
first word.

### The payload

The app reads only the notification's `data`. It carries no secret, no customer ID and no amount the app trusts:
everything shown comes from the customer's own data, loaded after sign-in.

```json
{
  "v": "1",
  "intent": "assist",
  "topic": "unusual_payment",
  "mode": "chat",
  "paymentId": "TXN-2291-20261006-34900",
  "transactionId": "",
  "view": ""
}
```

| Field | Values | Meaning |
|---|---|---|
| `v` | `"1"` | Anything else: ignore the notification's data and just open Home |
| `intent` | `assist`, `open` | `assist` may start a conversation; `open` only opens the screen |
| `topic` | see the table below | Picks the screen and whether it counts as a money topic |
| `mode` | `chat` (default), `call` | How to start |
| `paymentId` | `^TXN-\d{4}-\d{8}-\d{1,9}$` | A card payment (from `app/cards`) |
| `transactionId` | `^MH-\d{3}-\d{8}-\d{4}$` | A current account transaction (from `transactions`) |
| `view` | a Money Hub tab | Overrides the topic's tab |

### Topics

| `topic` | Money topic | Screen and context |
|---|---|---|
| `unusual_payment` | yes | Cards with `paymentId` chosen → `card_dispute`. Payment not found: Cards (`cards`) |
| `large_payment` | yes | Transaction details for `transactionId` (`money_hub`, `transactions`). Not found: Money Hub, Transactions |
| `money_out` | yes | Money Hub, `out` |
| `money_in`, `salary_in` | yes | Money Hub, `in` |
| `low_balance`, `bill_due` | yes | Money Hub, `expected` |
| `savings_goal` | yes | Money Hub, `goals` |
| `transfer` | yes | Accounts (`accounts`) |
| `spending_insight` | yes | Money Hub, `out` |
| `dispute_update` | yes | Cards › Your disputes (`cards`) |
| `mortgage` | no | Mortgages |
| anything else | no | Home |

### What the app does

1. Validate: unknown fields are ignored; IDs that don't match their pattern are dropped; an unknown `view` is
   dropped. The intent becomes `{topic, mode, screen, view?, paymentId?, transactionId?, autoStart}`, where
   `autoStart = intent == "assist" && topic is a money topic`.
2. Not signed in: keep the intent (in memory only) and run it right after sign-in. Sample mode opens the screen
   but can't start a conversation (the launcher says why).
3. Go to the screen. A `paymentId` must be one of `app/cards` `payments`; a `transactionId` must be found through
   `transactions` (filter `from` = `to` = the date in the ID, then match the ID). Not found: the topic's fallback.
4. When the screen has published the context the intent asked for (the same `page`, and `view` or `paymentId`
   when the intent names one) and `autoStart` is true; or, if that never comes, 6 s after arriving: open the assistant and start a `mode`
   conversation. A call still asks for the microphone first (V1). The screen's `draft` goes in the chat box.
5. A conversation is already going: don't start another. Go to the screen (the page move tells the assistant,
   6) and open the assistant.

It must work in all three cases: the app closed (the notification launched it), in the background (tapped from
the tray) and in the foreground (a push arriving while the app is open is shown again as a local notification
banner, so tapping it runs the same handler).

### Simulated push: real local notifications

Without push credentials, the apps simulate a push with a **local notification**: a real notification from the
phone's own notification system, in the tray and on the lock screen, carrying the same `data` as a push would.
Tapping it goes through exactly the same handler as a real push, so it starts the conversation in the mode that
notification names.

The **Notifications** screen (under More) lists sample notifications built from the customer's own data. Each
has a fixed `mode`, so both kinds can be shown:

| Sample | `topic` | `mode` | Built from |
|---|---|---|---|
| "Did you make this payment?" | `unusual_payment` | `chat` | The largest credit card payment in `app/cards` (newest if tied), by `paymentId` |
| "Your balance is getting low" | `low_balance` | `call` | The next bills in `hub` `forecast` |
| "Your salary has arrived" | `salary_in` | `chat` | The salary in `hub` `recurring` |
| "Your Holiday in Japan goal" | `savings_goal` | `call` | The first goal in `hub` `goals` (left out if there are none) |
| "A large payment left your account" | `large_payment` | `chat` | The largest money-out transaction on the first `transactions` page, by `transactionId` |

The title and body are worded from that data, for example "£612.00 at Sunshine Villas Booking on your credit card
ending 2291. Tap to chat with us." or "… Tap to call us."

Each row has **Send notification**, which schedules the local notification **5 seconds** later, so the tester
has time to lock the phone or leave the app. The row says "Sending in 5 seconds… lock your phone or leave the app
to see it arrive." Tapping the row itself runs the intent at once, without a notification.

| Case | What must happen |
|---|---|
| App open | The notification shows (iOS: foreground presentation as a banner; Android: a heads-up notification on a high-importance channel "Money alerts"). Tapping it runs the intent |
| App in the background | Tapping it brings the app forward and runs the intent |
| App closed (swiped away) | Tapping it launches the app; the launch reads the notification that opened it and runs the intent after sign-in has loaded |

Permission: ask for notification permission the first time **Send notification** is pressed (iOS
authorisation; Android 13+ `POST_NOTIFICATIONS`). Refused: "Allow notifications for this app in Settings to try
this." The rest of the screen still works.

A real push service (Firebase Cloud Messaging for both platforms) sits behind the same `PushSource` interface and
does nothing when the app has no push configuration; its taps go to the same handler. No push keys or Firebase
files go in the repository.

Connect's own chat push (`CreatePushNotificationRegistration`, B6) is a different feature (new chat messages while
the app is in the background) and isn't part of this.

## 8. Transaction details and the map

**Details** for a current account transaction: the merchant's tile and name, the amount (green with `+` when money
comes in, `−` when it goes out), date, category (with **Change category**, using `hub` `choices` and
`recategorise`, money in only to money-in categories and out to out), balance after, the reference
(`transactionId`), and where it happened.

**Where.** The sample data has no locations. `fixtures/merchant_places.json` maps each merchant (by the start of
its name, upper case) to an illustrative place `{name, area, lat, lng}` or to `{online: true}`. A physical place
shows a map with a pin (OpenStreetMap tiles in Flutter, with attribution; the platform map in React Native).
Online and direct debit payments show a card saying so, with no map. The places are made up for the demo, and the
screen says so in small print.

**Dispute this payment.** A debit card payment from the current account has the card payment ID
`TXN-<debit card ending>-<date without dashes>-<amount in pence>` (`moneyhub/data.py card_payments`). Show
**Dispute this payment** only when that ID is in `app/cards` `payments` (only the latest 25 are listed). It goes
to Cards with that payment chosen (`card_dispute`) and opens the assistant.

**Ask about this payment.** Opens the assistant with the screen's context and the `draft`
"About my £<amount> payment to <merchantName> on <d Month>: ".

## 9. Shared forms in a WebView

The mortgage and dispute forms are filled in by their assistants through Live Sync, which only exists for the web
(the Touchpoint web SDK). So the forms stay web pages, shown in a WebView.

| Form | URL | Who helps |
|---|---|---|
| Mortgage application | `<origin>/apply/about-you#k=<secret>` (the web app's own form page) | The form page's own assistant, today. The native launcher is hidden on this screen |
| Dispute form, from the chat's link (C9) | the exact link from the chat (`<disputePagesUrl>/…#k=…`), which is the dispute service's own form page | The conversation in the app: the link joins the form to it, as the texted link does |
| Dispute form, from the dispute watch (6) | `<origin>/cards/dispute#k=<secret>`, then the event `dispute:open` with `{sessionId}` | Needs web change W3; until then the page shows the customer's disputes and the form opens from the chat's link only |

**Locks** (S6): the WebView may load only `<origin>` and the `disputePagesUrl` origin; anything else opens in the
system browser. No file access, no mixed content. The app injects only the bridge shim below, and only into pages
from those origins.

**The bridge** (the contract in `connect-banking-app/docs/mobile/README.md` section 6). The app implements its
side now; the web side (W1 to W4) isn't wired yet, so today it does nothing:

- page → app: `startCall({applicationId, stage})` from the mortgage form's **Call us** button. React Native and
  Flutter define `window.AndroidBridge.startCall(json)` as a shim that posts to the app. The app checks
  `applicationId` against `^MA-[A-HJ-NP-Z2-9]{8}$` and `stage` against the mortgage stages
  (`about_you`, `property_loan`, `dip_result`, `product_selection`, `documents`, `review_submit`), then starts a
  call with `{page: "mortgage", stage, applicationId}`.
- app → page: once that call starts, `window.dispatchEvent(new CustomEvent('mortgage:call-started', {detail:
  {contactId}}))`; for the dispute watch, `dispute:open` with `{sessionId}`.

## 10. Architecture

Clean architecture, the same in both apps. Each feature has three layers, and dependencies point inwards only:

```
presentation  →  domain  ←  data
(screens,        (entities,     (DTOs, data sources:
 widgets,         repository     link transport, sample
 state)           interfaces,    transport, Participant
                  use cases)     Service, native call)
```

- **domain** has no framework imports (no Flutter, no React, no HTTP). Entities, value objects, repository
  interfaces and use cases, each use case one job (`StartChat`, `ParseAssistIntent`, `MatchCardPayment` …).
- **data** implements the domain's interfaces: DTOs to and from JSON, the transports, the Participant Service
  client, the native call bridge, secure storage.
- **presentation** holds screens, widgets and state, and talks only to use cases.
- **core** is shared, not a feature: configuration, the API transport and its errors, theme, routing, dependency
  wiring, formatting.

Features (folder names): `session` (sign-in, sign-out), `home`, `accounts`, `transactions` (list, details,
map), `cards` (cards, payments, disputes), `money_hub`, `mortgages`, `help`, `notifications` (push intents, the
sample inbox), `assistant` (screen context, chat, call, page moves, dispute watch, the sheet and launcher),
`settings`.

The assistant is one app-wide controller (it outlives screens, as the web widget outlives pages). Screens
publish their context to it; it never reaches into screens.

## 11. Look and feel

From `connect-banking-app/web/styles.css`, so the apps match the web app:

| Token | Light | Dark |
|---|---|---|
| brand (headers, primary buttons) | `#1a2b5f` | `#2a3f86` |
| brand-2 (accents, focus) | `#2a3f86` | `#3a52a8` |
| ink (text) | `#101631` | `#e8ebf7` |
| muted | `#5d6482` | `#9aa1bd` |
| line | `#e5e8f2` | `#2a3150` |
| background | `#f3f5fb` | `#0d1226` |
| card | `#ffffff` | `#151b34` |
| money in | `#0f8a66` (soft `#e5f5ef`) | `#34c294` (soft `#12352c`) |
| money out | `#c63d3d` (soft `#fbeaea`) | `#f07a7a` (soft `#3a1c22`) |
| flexible spending | `#e08a1e` | `#f2a64a` |
| essential spending | `#4864e6` | `#7d93ff` |
| savings | `#7b5cff` | `#a48cff` |
| corner radius | 16 | 16 |

- Bottom tabs: **Home**, **Accounts**, **Cards**, **Money Hub**, **More** (Mortgages, Help and FAQs,
  Notifications, Settings).
- The assistant launcher sits above the tab bar on every screen except the forms WebView, with the screen's
  `launcher` words and a live dot while a conversation is going. It opens the assistant as a bottom sheet;
  minimising keeps the conversation going, closing ends it. `[dock.js]`
- A thin **Demo · sample data** banner, as on every web page. Bank cards drawn as cards (navy debit, a different
  shade for credit) with only the last four digits.
- Amounts in pounds with two decimals and a real minus sign (`−£32.45`), money in green with `+`.
- Accessibility: every control has a label; text scales with the system setting; contrast as the web app.

## 12. Security rules

The rules S1 to S7 in `connect-banking-app/docs/mobile/README.md` apply. In this app:

- No AWS credentials, account details, instance or flow IDs, hosts or phone numbers anywhere in the code, config
  or docs. The origin comes from the link at run time.
- The session secret lives in the secure store. Participant, connection and attendee tokens live in memory only,
  and never go to logs, analytics or crash reports. Log route names and status codes, never bodies.
- HTTPS only (no cleartext exceptions); WebSocket `wss` only.
- The WebView locks of section 9.
- Push data is validated (section 7) and never trusted for identity or amounts.

## 13. Constants

| Name | Value | Source |
|---|---|---|
| Heartbeat | 10 s | `HEARTBEAT_MS` |
| Opener wait | 20 s | `READY_WAIT_MS` |
| Caption poll | 2 s | `TRANSCRIPT_EVERY_MS` |
| Call connect timeout | 25 s | `CONNECT_WAIT_MS` |
| Dispute watch | 4 s | `DISPUTE_WATCH_MS` |
| Page settle | 1.5 s | `PAGE_SETTLE_MS` |
| Disputes list refresh (Your disputes tab) | 5 s | `LIST_EVERY_MS` |
| Transactions page size | 25 | `money_api.web` |
| Push intent context wait | 6 s | new: start anyway if the screen hasn't published the asked-for context |
| Simulated push delay | 5 s | new |
