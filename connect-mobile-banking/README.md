# Mobile banking apps (Nationwide Building Society demo)

The internet banking app (`connect-banking-app/`) as a phone app, built twice from one design: once in **Flutter**
and once in **React Native**. Both have the same screens and the same assistant as the web app. Chat and calls
reach ARIA and her specialists through Amazon Connect, the assistant knows which screen the customer is on, and a
push notification about money opens the right screen and starts a chat or call there.

> **Demo.** Sample data only (James, `CUST-001`), with a banner saying so on every screen, as on the web app.

| Folder | What |
|---|---|
| [`docs/CONTRACT.md`](docs/CONTRACT.md) | The one design both apps follow: backend routes, screen context, chat and call rules, push intents, the map, forms, architecture, theme, security |
| [`flutter_app/`](flutter_app/) | The Flutter app ([its README](flutter_app/README.md)) |
| [`react_native_app/`](react_native_app/) | The React Native app ([its README](react_native_app/README.md)) |
| `fixtures/` | Sample mode data: the banking app's own replies for the sample customer, plus illustrative merchant places for the map |
| `scripts/make_fixtures.py` | Makes `fixtures/` from the banking app's own code, in memory (no AWS) |

## Contents

- [What the apps do](#what-the-apps-do)
- [How they connect](#how-they-connect)
- [Push notifications into the assistant](#push-notifications-into-the-assistant)
- [Architecture](#architecture)
- [Run them](#run-them)
- [What isn't done yet](#what-isnt-done-yet)

## What the apps do

| Screen | What's on it | Who helps when you chat or call from it |
|---|---|---|
| Home | Greeting, accounts, latest payments | ARIA |
| Accounts | Current account and saver, each with its movements | ARIA |
| Transactions and details | Every payment; details with a map of where it happened, the category (changeable), and **Dispute this payment** for a card payment | The Money Hub agent, through ARIA |
| Cards | Cards, card payments with **Dispute**, and **Your disputes** | ARIA; after **Dispute**, the card dispute assistant with that payment |
| Money Hub | Money out, Money in, Expected, Transactions and Goals tabs, with charts | The Money Hub agent, told which tab |
| Mortgages | Products and the application form | ARIA about mortgages; the form's own assistant fills the form |
| Help and FAQs | Common questions, your disputes | ARIA |
| Notifications | Alerts about your money; tapping one opens the assistant there | Whoever helps on that screen |

## How they connect

The same way the web app does, against the same deployed backend, with no AWS changes:

1. The customer opens the app from their internet banking link. The link's address is the backend, and its
   secret (after `#k=`) stands for the signed-in customer. The app keeps it in the phone's secure store.
2. Every request is `POST <app-host>/api/<route>` with that secret in the body. The server decides who the
   customer is; the app never says.
3. A chat or call starts on the server (`contact/chat`, `contact/call`), with the screen's context. The app gets
   only what it needs to join that one conversation.
4. Chat runs over the Amazon Connect Participant Service (HTTPS and a websocket), a straight port of the web
   widget. Calls run on the Amazon Chime SDK through a small native module in each app.
5. During a conversation the app tells the server when the customer moves screen, so ARIA can bring in the right
   specialist, and watches for the dispute assistant sending its form.

The production path, with the bank's own sign-in in place of the link, is described in
`connect-banking-app/docs/mobile/README.md` (B1 to B9). Each app keeps its transport behind one interface, so that
change doesn't touch any screen.

## Push notifications into the assistant

A notification's data names a **topic**, for example `unusual_payment`, `low_balance` or `salary_in`, and
optionally a payment or transaction. Tapping it:

1. checks the data (unknown values are dropped; it never carries a secret, a customer ID or an amount the app trusts);
2. opens the screen for that topic, for example Cards with that payment chosen, or the Money Hub's Expected tab;
3. for a money topic, opens the assistant and starts a chat or call there. The server then routes it to the right
   assistant with that screen's context, and the chat box offers a first question the customer can send or change.

This works when the app is closed, in the background or open. If the customer isn't signed in, the app keeps the
notification and acts on it straight after sign-in.

**Try it without push keys.** Each app's **Notifications** screen (under More) lists sample alerts made from the
customer's own data. **Send notification** puts a real notification on the phone 5 seconds later, through the
phone's own notification system, with the same data a push would carry. Lock the phone or leave the app, then tap
it when it arrives:

| Sample | Starts |
|---|---|
| Did you make this payment? (the largest credit card payment) | A **chat** with the card dispute assistant about that payment |
| Your balance is getting low | A **call** about what's coming out (Money Hub, Expected) |
| Your salary has arrived | A **chat** about money in (Money Hub, Money in) |
| Your savings goal | A **call** about the goal (Money Hub, Goals) |
| A large payment left your account | A **chat** on that payment's details |

The full rules are in [docs/CONTRACT.md section 7](docs/CONTRACT.md#7-push-notifications-that-open-the-assistant).

## Architecture

Both apps use clean architecture with the same features and layers:

```
core/                        configuration, API transport, theme, routing, dependency wiring, formatting
features/<feature>/
  domain/                    entities, repository interfaces, use cases (no framework imports)
  data/                      DTOs, transports, Participant Service client, native call bridge, secure store
  presentation/              screens, widgets, state
```

Features: `session`, `home`, `accounts`, `transactions`, `cards`, `money_hub`, `mortgages`, `help`,
`notifications`, `assistant`, `settings`. The assistant is one app-wide controller. Screens publish their context
to it, as each web page does to the web widget.

## Run them

See each app's README for the full steps:

- Flutter: [`flutter_app/README.md`](flutter_app/README.md)
- React Native: [`react_native_app/README.md`](react_native_app/README.md)

Both start in **Sample mode** without any backend. For **Link mode**, paste an internet banking demo link
(`deploy_banking_app.sh` prints one) on the sign-in screen.

To remake the sample data after the banking app changes:

```bash
python3 /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/scripts/make_fixtures.py /Users/alokkulkarni/Documents/Development/awsagentcore/connect-mobile-banking/fixtures
```

Then copy `fixtures/` into each app, as its README says.

## What isn't done yet

| Gap | Effect | Needs |
|---|---|---|
| Web changes W1 to W5 (`connect-banking-app/docs/mobile/README.md` section 6) | The mortgage form in the app uses its own web assistant, not the app's. A dispute form the server opens during a call can't open in the app; one posted in a chat can | Changes to `connect-banking-app/web` and its Lambda |
| Universal Links and App Links | Opening the link on the phone doesn't open the app; paste it instead | W5, and the app's signing details in the link files |
| Push service | Real notifications need the bank's APNs key and a Firebase project | Each app's README, "Push" |
| The face on video | Calls are voice only in the apps | Not planned for mobile |
