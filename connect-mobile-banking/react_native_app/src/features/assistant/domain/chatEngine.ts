// A chat with the assistant: a port of the web widget's talk.js (chat parts) to the Amazon Connect Participant
// Service, with no framework in it. Rule numbers are CONTRACT.md section 4.
//   The app's backend starts the contact (it alone knows who this is); the app joins it with the participant token.
//   Tokens live only in this object's memory, never in storage or logs.
import { CHAT_ENDED, TIMINGS } from '../../../core/config/appConfig';
import { plain } from '../../../core/format/messageLayout';
import type { TimerHandle, Timers } from '../../../core/util/timers';
import type { AssistantApi, ChatSocket, ParticipantPort, SocketFactory } from './ports';
import type { PageFields } from './screenContext';

export type ChatLine = { id: string; who: 'me' | 'them'; text: string; formLink?: string };

export type StartedInfo = { kind: 'chat' | 'call'; journey: string; contactId: string };

export interface ConversationEvents {
  status(words: string): void;
  line(line: ChatLine): void;
  input(enabled: boolean): void;
  started(info: StartedInfo): void;
  ended(words: string, hadContact: boolean): void;
  activity(): void;
}

// Back from a specialist on a chat: the note the app sends ARIA. Never shown (C6).
const RETURN_NOTES = ['Back from card dispute:', 'Back from mortgage application:'];
export const isReturnNote = (words: string): boolean => RETURN_NOTES.some((label) => (words || '').trim().startsWith(label));

// The dispute assistant's form link in a message (C9): its pages' address followed by #k=<secret>. The exact link.
export function disputeFormLink(words: string, disputePagesUrl: string): string {
  if (!disputePagesUrl) return '';
  const at = words.indexOf(disputePagesUrl);
  if (at < 0) return '';
  const found = words.slice(at).match(/#k=[A-Za-z0-9_-]{16,128}/);
  if (!found || found.index === undefined) return '';
  const link = words.slice(at, at + found.index + found[0].length);
  return /\s/.test(link) ? '' : link;
}

type Item = { Id?: string; Type?: string; ContentType?: string; ParticipantRole?: string; Content?: string };

type Live = {
  region: string;
  participantToken: string;
  connectionToken: string;
  contactId: string;
  journey: string;
  opener: string;
  socket: ChatSocket | null;
  heartbeat: TimerHandle | null;
  openerTimer: TimerHandle | null;
  opened: boolean;
  askingReturn: boolean;
  returnKey: string;
};

export type ChatDeps = {
  api: AssistantApi;
  participant: ParticipantPort;
  sockets: SocketFactory;
  timers: Timers;
  uuid: () => string;
  disputePagesUrl: () => string;
  events: ConversationEvents;
};

export class ChatEngine {
  private live: Live | null = null;
  private readonly seen = new Set<string>();
  private background = false;
  private counter = 0;

  constructor(private readonly d: ChatDeps) {}

  get active(): boolean {
    return this.live !== null;
  }

  get contactId(): string {
    return this.live?.contactId || '';
  }

  // C1, C2: start the contact on the server, then join it.
  async start(fields: PageFields): Promise<void> {
    if (this.live) return;
    this.seen.clear();
    this.d.events.input(false);
    this.d.events.status('Connecting you…');
    try {
      const started = await this.d.api.startChat(fields);
      this.live = {
        region: started.region,
        participantToken: started.participantToken,
        connectionToken: '',
        contactId: started.contactId,
        journey: started.journey,
        opener: started.opener || '',
        socket: null,
        heartbeat: null,
        openerTimer: null,
        opened: false,
        askingReturn: false,
        returnKey: '',
      };
      this.d.events.started({ kind: 'chat', journey: started.journey, contactId: started.contactId });
      await this.connect(this.live);
    } catch (error) {
      this.finish(error instanceof Error ? error.message : "We couldn't connect the conversation. Please try again.");
    }
  }

  private async connect(current: Live): Promise<void> {
    // No ConnectParticipant: that's for streaming and agents.
    const joined = await this.d.participant.post(current.region, 'connection', current.participantToken, { Type: ['WEBSOCKET', 'CONNECTION_CREDENTIALS'] });
    if (this.live !== current) return;
    current.connectionToken = joined.ConnectionCredentials.ConnectionToken;
    const socket = this.d.sockets(joined.Websocket.Url);
    current.socket = socket;
    socket.onOpen = async () => {
      if (this.live !== current) return;
      // C3
      socket.send(JSON.stringify({ topic: 'aws/subscribe', content: { topics: ['aws/chat'] } }));
      current.heartbeat = this.d.timers.setInterval(() => socket.send(JSON.stringify({ topic: 'aws/heartbeat' })), TIMINGS.heartbeatMs);
      if (!current.opened) {
        this.d.events.status('Connecting you to our assistant…');
        this.d.events.input(false);
      }
      // C4: anything said before the socket was listening, the latest 100, oldest first.
      const transcript = await this.d.participant
        .post(current.region, 'transcript', current.connectionToken, { MaxResults: 100, ScanDirection: 'BACKWARD', SortOrder: 'ASCENDING' })
        .catch(() => ({}));
      ((transcript as { Transcript?: Item[] }).Transcript || []).forEach((item) => this.handleItem(item));
      if (this.live === current && !current.opened && !current.openerTimer) {
        current.openerTimer = this.d.timers.setTimeout(() => this.sendOpener(), TIMINGS.openerWaitMs);
      }
    };
    socket.onMessage = (text: string) => {
      let frame: { topic?: string; content?: string };
      try {
        frame = JSON.parse(text);
      } catch {
        return;
      }
      if (frame.topic !== 'aws/chat' || !frame.content) return; // C5
      try {
        this.handleItem(JSON.parse(frame.content));
      } catch {
        /* not a chat item */
      }
    };
    socket.onClose = () => {
      if (this.live !== current || current.socket !== socket) return;
      this.d.timers.clearInterval(current.heartbeat);
      current.heartbeat = null;
      current.socket = null;
      if (!this.background) this.finish('The chat has ended.'); // C10; in the background, C13 reconnects later
    };
  }

  // C5 to C10: one item from the socket or the transcript.
  handleItem(item: Item): void {
    if (!item || (item.Id && this.seen.has(item.Id))) return;
    if (item.Id) this.seen.add(item.Id);
    if (item.Type === 'MESSAGE') {
      const content = item.Content || '';
      const role = item.ParticipantRole;
      if (role === 'CUSTOMER' && isReturnNote(content)) return; // ours, not theirs
      if (content.trim()) this.show(item.Id || `m${++this.counter}`, role === 'CUSTOMER', content);
      if (role !== 'CUSTOMER') {
        if (this.live && this.live.opened && !content.trim()) this.sendReturnNote(); // C8: ARIA's bot block started again
        this.sendOpener(); // C7: she's listening now
      }
    }
    if (item.Type === 'EVENT' && item.ContentType === CHAT_ENDED) this.finish('The chat has ended.');
  }

  private show(id: string, me: boolean, words: string): void {
    const formLink = me ? '' : disputeFormLink(words, this.d.disputePagesUrl());
    this.d.events.line({ id, who: me ? 'me' : 'them', text: me ? plain(words) : words, ...(formLink ? { formLink } : {}) });
    if (!me) this.d.events.activity(); // C15
  }

  // C7: the first thing the customer says, worded by the server for the screen. Sent once.
  private sendOpener(): void {
    const live = this.live;
    if (!live || live.opened || !live.connectionToken) return;
    live.opened = true;
    this.d.timers.clearTimeout(live.openerTimer);
    live.openerTimer = null;
    if (live.opener) {
      this.message(live, live.opener).catch((error: Error) => this.d.events.status(error.message));
    }
    this.d.events.input(true);
    this.d.events.status('Connected.');
  }

  // C8: back to ARIA from a specialist: her note, once per return.
  private async sendReturnNote(): Promise<void> {
    const current = this.live;
    if (!current || current.askingReturn || !current.connectionToken) return;
    current.askingReturn = true;
    try {
      const back = await this.d.api.returned(current.contactId);
      if (this.live === current && back.note && back.key !== current.returnKey) {
        current.returnKey = back.key;
        await this.message(current, back.note);
      }
    } catch {
      /* ARIA still answers the customer's next message */
    }
    current.askingReturn = false;
  }

  private message(live: Live, words: string) {
    return this.d.participant.post(live.region, 'message', live.connectionToken, { ContentType: 'text/plain', Content: words, ClientToken: this.d.uuid() });
  }

  // C11
  async send(words: string): Promise<void> {
    const text = words.trim();
    const live = this.live;
    if (!text || !live || !live.connectionToken) return;
    try {
      await this.message(live, text);
    } catch (error) {
      this.d.events.status(error instanceof Error ? error.message : 'Your message could not be sent.');
    }
  }

  // C12: leave properly, so Connect ends the contact rather than waiting.
  async end(words = 'You ended the chat.'): Promise<void> {
    const live = this.live;
    if (!live) return;
    try {
      const token =
        live.connectionToken ||
        (await this.d.participant.post(live.region, 'connection', live.participantToken, { Type: ['CONNECTION_CREDENTIALS'] })).ConnectionCredentials.ConnectionToken;
      await this.d.participant.post(live.region, 'disconnect', token, { ClientToken: this.d.uuid() });
    } catch {
      /* the contact may already have ended */
    }
    this.finish(words);
  }

  // C13: the background never ends a chat; back in the foreground, rejoin if the socket closed meanwhile.
  async setForeground(foreground: boolean): Promise<void> {
    this.background = !foreground;
    const live = this.live;
    if (!foreground || !live || live.socket) return;
    try {
      await this.connect(live);
    } catch {
      this.finish('The chat has ended.');
    }
  }

  // C14
  private finish(words: string): void {
    const current = this.live;
    this.live = null;
    if (current) {
      this.d.timers.clearInterval(current.heartbeat);
      this.d.timers.clearTimeout(current.openerTimer);
      try {
        current.socket?.close();
      } catch {
        /* already closed */
      }
    }
    this.seen.clear();
    this.d.events.input(false);
    this.d.events.status(words);
    this.d.events.ended(words, Boolean(current));
  }
}
