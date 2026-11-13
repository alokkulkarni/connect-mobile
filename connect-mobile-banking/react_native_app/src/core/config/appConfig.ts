// The app's timings and limits, the same as the internet banking web app's (CONTRACT.md section 13). Nothing here
// names an account, a host or an instance: the bank's address comes from the customer's link at run time.

export const TIMINGS = {
  heartbeatMs: 10_000, //        talk.js HEARTBEAT_MS
  openerWaitMs: 20_000, //       talk.js READY_WAIT_MS
  captionPollMs: 2_000, //       talk.js TRANSCRIPT_EVERY_MS
  callConnectMs: 25_000, //      talk.js CONNECT_WAIT_MS
  disputeWatchMs: 4_000, //      app.js DISPUTE_WATCH_MS
  pageSettleMs: 1_500, //        app.js PAGE_SETTLE_MS
  disputesListMs: 5_000, //      cards.js LIST_EVERY_MS
  autoStartWaitMs: 6_000, //     a push intent waits this long for its screen's context, then starts anyway
} as const;

export const TRANSACTIONS_PAGE_SIZE = 25;

// The Participant Service: plain HTTPS with the participant or connection token, no AWS credentials.
export const participantBase = (region: string) => `https://participant.connect.${region}.amazonaws.com/participant`;

export const CHAT_ENDED = 'application/vnd.amazonaws.connect.event.chat.ended';
