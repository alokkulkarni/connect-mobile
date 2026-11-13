// A call with the assistant, audio only (CONTRACT.md section 5). This owns the sequence; the native module (the
// Amazon Chime SDK) only joins, mutes and leaves. A port of talk.js startCall, readTranscript, toggleMute, hangUp.
import { TIMINGS } from '../../../core/config/appConfig';
import type { TimerHandle, Timers } from '../../../core/util/timers';
import type { ConversationEvents } from './chatEngine';
import type { AssistantApi, CallBridge, CallEvent, Microphone, ParticipantPort } from './ports';
import type { PageFields } from './screenContext';

export const COULD_NOT_CONNECT = "The call couldn't connect. A VPN or work network can block calls: try another network, or use Chat.";
export const MIC_REFUSED = 'To call, allow this app to use your microphone.';

export interface CallEvents extends ConversationEvents {
  muted(muted: boolean): void;
  colleague(): void;
}

type Live = {
  region: string;
  participantToken: string;
  contactId: string;
  transcript: boolean;
  connected: boolean;
  muted: boolean;
  withPerson: boolean;
  reading: boolean;
  poll: TimerHandle | null;
  connecting: TimerHandle | null;
  stopListening: () => void;
};

export type CallDeps = {
  api: AssistantApi;
  participant: ParticipantPort;
  bridge: CallBridge;
  microphone: Microphone;
  timers: Timers;
  uuid: () => string;
  events: CallEvents;
};

export class CallEngine {
  private live: Live | null = null;
  private starting = false;
  private readonly seen = new Set<string>();

  constructor(private readonly d: CallDeps) {}

  get active(): boolean {
    return this.live !== null || this.starting;
  }

  get contactId(): string {
    return this.live?.contactId || '';
  }

  async start(fields: PageFields): Promise<void> {
    if (this.active) return;
    this.starting = true;
    this.seen.clear();
    this.d.events.status('Starting your call…');
    try {
      // V1: the microphone first, so a refusal costs nothing.
      if (!(await this.d.microphone.request())) {
        this.starting = false;
        this.finish(MIC_REFUSED);
        return;
      }
      const started = await this.d.api.startCall(fields); // V2
      const current: Live = {
        region: started.region,
        participantToken: started.participantToken,
        contactId: started.contactId,
        transcript: Boolean(started.transcript),
        connected: false,
        muted: false,
        withPerson: false,
        reading: false,
        poll: null,
        connecting: null,
        stopListening: () => {},
      };
      this.live = current;
      this.starting = false;
      this.d.events.started({ kind: 'call', journey: started.journey, contactId: started.contactId });
      current.stopListening = this.d.bridge.onEvent((event) => this.onBridge(current, event));
      if (current.transcript) current.poll = this.d.timers.setInterval(() => this.readTranscript(current), TIMINGS.captionPollMs); // V6
      await this.d.bridge.join(started.meeting, started.attendee); // V3
      if (this.live !== current) return;
      if (!current.connected) this.d.events.status('Connecting your call…');
      current.connecting = this.d.timers.setTimeout(() => {
        if (this.live === current && !current.connected) this.hangUp(COULD_NOT_CONNECT); // V5
      }, TIMINGS.callConnectMs);
    } catch (error) {
      this.starting = false;
      this.finish(error instanceof Error && error.message ? error.message : 'The call could not start.');
    }
  }

  // V4: what the native side says.
  private onBridge(current: Live, event: CallEvent): void {
    if (this.live !== current) return;
    switch (event.type) {
      case 'connected':
        current.connected = true;
        this.d.timers.clearTimeout(current.connecting);
        this.d.events.status(
          `Connected. Speak when you're ready${current.transcript ? "; what's said appears below" : ''}. Headphones give the clearest call.`,
        );
        break;
      case 'stopped':
        this.finish(current.connected ? 'The call has ended.' : COULD_NOT_CONNECT); // V9
        break;
      case 'muted':
        current.muted = event.muted;
        this.d.events.muted(event.muted);
        break;
      case 'error':
        this.hangUp(event.message || 'The call could not start.');
        break;
    }
  }

  // V6: new lines of what's been said, each once, oldest first.
  private async readTranscript(current: Live): Promise<void> {
    if (this.live !== current || current.reading) return;
    current.reading = true;
    try {
      const said = await this.d.api.transcript(current.contactId);
      if (this.live !== current) return;
      if (said.unavailable) this.d.timers.clearInterval(current.poll);
      if (said.withPerson && !current.withPerson) {
        current.withPerson = true;
        this.d.events.status('A colleague has joined the call.');
        this.d.events.colleague();
      }
      for (const line of said.lines || []) {
        const key = `${line.at}|${line.who}|${line.text}`;
        if (this.seen.has(key)) continue;
        this.seen.add(key);
        this.d.events.line({ id: key, who: line.who === 'customer' ? 'me' : 'them', text: line.text });
        if (line.who !== 'customer') this.d.events.activity();
      }
    } catch {
      /* try again on the next tick */
    }
    current.reading = false;
  }

  // V7
  async toggleMute(): Promise<void> {
    const live = this.live;
    if (!live) return;
    const next = !live.muted;
    live.muted = next;
    this.d.events.muted(next);
    await this.d.bridge.setMuted(next).catch(() => {});
  }

  // V8: the participant leaves first, so Connect ends the contact at once; then the meeting.
  async hangUp(words = 'You ended the call.'): Promise<void> {
    const live = this.live;
    if (!live) return;
    try {
      const joined = await this.d.participant.post(live.region, 'connection', live.participantToken, { Type: ['CONNECTION_CREDENTIALS'] });
      await this.d.participant.post(live.region, 'disconnect', joined.ConnectionCredentials.ConnectionToken, { ClientToken: this.d.uuid() });
    } catch {
      /* the contact may already have ended */
    }
    this.finish(words);
  }

  private finish(words: string): void {
    const current = this.live;
    this.live = null;
    if (current) {
      this.d.timers.clearInterval(current.poll);
      this.d.timers.clearTimeout(current.connecting);
      current.stopListening();
      this.d.bridge.leave().catch(() => {});
    }
    this.seen.clear();
    this.d.events.muted(false);
    this.d.events.status(words);
    this.d.events.ended(words, Boolean(current));
  }
}
