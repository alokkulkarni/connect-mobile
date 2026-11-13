// The assistant, app-wide: one conversation at a time (chat or call), whichever screen the customer is on. It
// outlives screens, as the web widget outlives pages. Screens publish their context to it; it never reaches into
// screens: it tells the app what to open through listeners (a form, a refresh).
import { TIMINGS } from '../../../core/config/appConfig';
import { Observable, Timers } from '../../../core/util/timers';
import { CallEngine } from './callEngine';
import { ChatEngine, ChatLine, ConversationEvents, StartedInfo } from './chatEngine';
import { DisputeWatch, PageMoveTracker } from './following';
import type { AssistantApi, CallBridge, Microphone, ParticipantPort, SocketFactory } from './ports';
import { HOME_CONTEXT, ScreenContext, pageFields } from './screenContext';

export type Kind = 'chat' | 'call';

export type AssistantState = {
  open: boolean; //            the sheet is showing
  context: ScreenContext;
  available: boolean; //       chat and calls are on (app/home `talk`)
  kind: Kind | null; //        the conversation going on now
  connected: boolean;
  status: string;
  lines: ChatLine[];
  inputEnabled: boolean;
  muted: boolean;
  withPerson: boolean;
  draft: string;
};

export type FormRequest = { kind: 'link'; url: string } | { kind: 'disputeSession'; sessionId: string };

export const UNAVAILABLE_WORDS = 'Chat and calls need your internet banking link. Open the app from your link to talk to us.';
export const DISPUTE_OPENED_WORDS = 'Your dispute is open on the Cards screen, under Your disputes. Watch it fill in as you talk.';

export type AssistantDeps = {
  api: AssistantApi;
  participant: ParticipantPort;
  sockets: SocketFactory;
  bridge: CallBridge;
  microphone: Microphone;
  timers: Timers;
  uuid: () => string;
};

// A push intent waiting for its screen: `matches` says when the published context is the one it asked for.
type Pending = { mode: Kind; matches: (context: ScreenContext) => boolean; timer: unknown };

export class AssistantController extends Observable<AssistantState> {
  private readonly chat: ChatEngine;
  private readonly call: CallEngine;
  private readonly moves: PageMoveTracker;
  private readonly watch: DisputeWatch;
  private disputePagesUrl = '';
  private pending: Pending | null = null;
  private readonly formListeners = new Set<(request: FormRequest) => void>();
  private readonly activityListeners = new Set<() => void>();
  private readonly startedListeners = new Set<(info: StartedInfo) => void>();

  constructor(private readonly d: AssistantDeps) {
    super({
      open: false,
      context: HOME_CONTEXT,
      available: false,
      kind: null,
      connected: false,
      status: '',
      lines: [],
      inputEnabled: false,
      muted: false,
      withPerson: false,
      draft: '',
    });
    const events = (kind: Kind): ConversationEvents => ({
      status: (status) => this.set({ status }),
      line: (line) => this.set({ lines: [...this.state.lines, line] }),
      input: (inputEnabled) => this.set({ inputEnabled, connected: kind === 'chat' ? inputEnabled || this.state.connected : this.state.connected }),
      started: (info) => this.onStarted(info),
      ended: (_words, hadContact) => this.onEnded(hadContact),
      activity: () => this.activityListeners.forEach((l) => l()),
    });
    this.chat = new ChatEngine({ ...d, disputePagesUrl: () => this.disputePagesUrl, events: events('chat') });
    this.call = new CallEngine({
      ...d,
      events: {
        ...events('call'),
        status: (status) => this.set({ status, connected: this.state.connected || status.startsWith('Connected') }),
        muted: (muted) => this.set({ muted }),
        colleague: () => this.set({ withPerson: true }),
      },
    });
    this.moves = new PageMoveTracker(d.timers, TIMINGS.pageSettleMs, () => this.state.context, (id, fields) => d.api.pageMoved(id, fields));
    this.watch = new DisputeWatch(
      d.timers,
      TIMINGS.disputeWatchMs,
      { live: (id) => d.api.disputesLive(id), open: (id, disputeId) => d.api.disputesOpen(id, disputeId) },
      (sessionId) => {
        this.formListeners.forEach((l) => l({ kind: 'disputeSession', sessionId }));
        this.set({ status: DISPUTE_OPENED_WORDS });
      },
    );
  }

  // ── set-up ────────────────────────────────────────────────────────────────

  configure(available: boolean, disputePagesUrl: string): void {
    this.disputePagesUrl = disputePagesUrl;
    this.set({ available, status: available ? this.state.status : UNAVAILABLE_WORDS });
  }

  onForm(listener: (request: FormRequest) => void) {
    this.formListeners.add(listener);
    return (): void => {
      this.formListeners.delete(listener);
    };
  }

  onActivity(listener: () => void) {
    this.activityListeners.add(listener);
    return (): void => {
      this.activityListeners.delete(listener);
    };
  }

  onStartedConversation(listener: (info: StartedInfo) => void) {
    this.startedListeners.add(listener);
    return (): void => {
      this.startedListeners.delete(listener);
    };
  }

  // ── where the customer is ─────────────────────────────────────────────────

  setContext(context: ScreenContext): void {
    this.set({ context });
    this.moves.changed();
    if (this.pending && this.pending.matches(context)) this.runPending();
  }

  // ── the sheet ─────────────────────────────────────────────────────────────

  open(draft?: string): void {
    const offered = draft ?? this.state.context.draft ?? '';
    this.set({ open: true, draft: this.state.draft || offered });
  }

  minimise(): void {
    this.set({ open: false });
  }

  // Closing ends any conversation; minimising keeps it going behind the launcher (dock.js).
  async close(): Promise<void> {
    this.set({ open: false });
    await this.end();
  }

  setDraft(draft: string): void {
    this.set({ draft });
  }

  // ── conversations ─────────────────────────────────────────────────────────

  get live(): boolean {
    return this.state.kind !== null || this.chat.active || this.call.active;
  }

  async startChat(): Promise<void> {
    if (!this.guard()) return;
    this.begin('chat');
    await this.chat.start(pageFields(this.state.context));
  }

  async startCall(fields = pageFields(this.state.context)): Promise<void> {
    if (!this.guard()) return;
    this.begin('call');
    await this.call.start(fields);
  }

  // The mortgage form's own "Call us" (the bridge, CONTRACT.md section 9).
  async startFormCall(applicationId: string, stage: string): Promise<void> {
    await this.startCall({ page: 'mortgage', view: '', stage, applicationId, paymentId: '' });
  }

  async send(): Promise<void> {
    const words = this.state.draft;
    if (!words.trim()) return;
    this.set({ draft: '' });
    await this.chat.send(words);
  }

  toggleMute(): Promise<void> {
    return this.call.toggleMute();
  }

  async end(): Promise<void> {
    if (this.chat.active) await this.chat.end();
    if (this.call.active) await this.call.hangUp();
  }

  // The chat's own "Open the form here" (C9).
  openFormLink(url: string): void {
    this.watch.markOpened();
    this.formListeners.forEach((l) => l({ kind: 'link', url }));
  }

  setForeground(foreground: boolean): void {
    this.chat.setForeground(foreground);
  }

  // ── push intents (CONTRACT.md section 7) ──────────────────────────────────

  // Start a `mode` conversation once the screen has published the context the intent asked for (or after a short
  // wait). A conversation already going: just open the sheet.
  autoStart(mode: Kind, matches: (context: ScreenContext) => boolean): void {
    this.clearPending();
    if (this.live) {
      this.open();
      return;
    }
    const timer = this.d.timers.setTimeout(() => this.runPending(), TIMINGS.autoStartWaitMs);
    this.pending = { mode, matches, timer };
    if (matches(this.state.context)) this.runPending();
  }

  // The intent's screen fell back to another (its payment or transaction wasn't found): wait for that one instead.
  retarget(screen: string): void {
    if (!this.pending) return;
    this.pending.matches = (context) => context.screen === screen;
    if (this.state.context.screen === screen) this.runPending();
  }

  private runPending(): void {
    const pending = this.pending;
    this.clearPending();
    if (!pending) return;
    this.open();
    if (this.live) return;
    if (!this.state.available) {
      this.set({ status: UNAVAILABLE_WORDS });
      return;
    }
    if (pending.mode === 'call') this.startCall();
    else this.startChat();
  }

  private clearPending(): void {
    if (this.pending) this.d.timers.clearTimeout(this.pending.timer);
    this.pending = null;
  }

  // ── internals ─────────────────────────────────────────────────────────────

  private guard(): boolean {
    if (this.live) return false;
    if (!this.state.available) {
      this.set({ open: true, status: UNAVAILABLE_WORDS });
      return false;
    }
    return true;
  }

  private begin(kind: Kind): void {
    const draft = kind === 'chat' ? this.state.draft || this.state.context.draft || '' : this.state.draft;
    this.set({ open: true, kind, connected: false, lines: [], muted: false, withPerson: false, inputEnabled: false, draft });
  }

  private onStarted(info: StartedInfo): void {
    this.moves.begin(info.contactId, this.state.context);
    this.watch.begin(info.contactId);
    this.startedListeners.forEach((l) => l(info));
  }

  private onEnded(hadContact: boolean): void {
    this.moves.end();
    this.watch.end();
    // A finished conversation leaves only a one-line note of how it ended (C14).
    this.set({ kind: null, connected: false, lines: [], inputEnabled: false, muted: false, withPerson: false });
    if (hadContact) this.activityListeners.forEach((l) => l()); // C15
  }
}
