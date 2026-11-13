// The app's fixed settings: the timings of the internet banking web app (docs/CONTRACT.md section 13), so the
// assistant behaves the same here as on the web. Nothing here names an account, an instance or a host: the
// backend's address comes from the customer's own link at run time.

class AppTimings {
  const AppTimings({
    this.heartbeat = const Duration(seconds: 10),
    this.openerWait = const Duration(seconds: 20),
    this.captionPoll = const Duration(seconds: 2),
    this.callConnectTimeout = const Duration(seconds: 25),
    this.disputeWatch = const Duration(seconds: 4),
    this.pageSettle = const Duration(milliseconds: 1500),
    this.disputesListRefresh = const Duration(seconds: 5),
  });

  final Duration heartbeat; // aws/heartbeat on the chat websocket   [talk.js HEARTBEAT_MS]
  final Duration openerWait; // send the opener anyway after this     [talk.js READY_WAIT_MS]
  final Duration captionPoll; // contact/transcript during a call      [talk.js TRANSCRIPT_EVERY_MS]
  final Duration callConnectTimeout; // hang up if audio hasn't connected [talk.js CONNECT_WAIT_MS]
  final Duration disputeWatch; // disputes/live during a conversation [app.js DISPUTE_WATCH_MS]
  final Duration pageSettle; // a screen kept this long is told to the assistant [app.js PAGE_SETTLE_MS]
  final Duration disputesListRefresh; // Your disputes follows a dispute being filled in [cards.js LIST_EVERY_MS]
}

const appTimings = AppTimings();

/// Transactions per page, as the Money Hub's own route returns them.
const transactionsPageSize = 25;

/// The OpenStreetMap tile server's user agent asks for the app's package name.
const mapUserAgentPackage = 'com.example.connectbanking.connect_banking';
