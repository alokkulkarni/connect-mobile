// Fakes for the assistant's ports: no network, no device. Used by the *.test.ts files beside it.
import { realTimers } from '../../../core/util/timers';
import type { ChatLine, ConversationEvents, StartedInfo } from './chatEngine';
import type { AssistantApi, CallBridge, CallEvent, ChatSocket, ParticipantPort } from './ports';

export const flush = async (times = 12) => {
  for (let i = 0; i < times; i++) await Promise.resolve();
};

export class FakeSocket implements ChatSocket {
  sent: string[] = [];
  closed = false;
  onOpen = () => {};
  onMessage = (_text: string) => {};
  onClose = () => {};
  send(text: string) {
    this.sent.push(text);
  }
  close() {
    this.closed = true;
  }
  // A chat item arriving on the socket.
  item(item: Record<string, unknown>) {
    this.onMessage(JSON.stringify({ topic: 'aws/chat', content: JSON.stringify(item) }));
  }
}

export function fakeParticipant(transcript: Record<string, unknown>[] = []) {
  const calls: { path: string; bearer: string; body: Record<string, unknown> }[] = [];
  let connections = 0;
  const participant: ParticipantPort = {
    post: async (_region, path, bearer, body) => {
      calls.push({ path, bearer, body });
      if (path === 'connection') {
        connections += 1;
        return { ConnectionCredentials: { ConnectionToken: `conn-${connections}` }, Websocket: { Url: 'wss://socket.example' } } as any;
      }
      if (path === 'transcript') return { Transcript: transcript } as any;
      return {} as any;
    },
  };
  return { participant, calls, messages: () => calls.filter((c) => c.path === 'message').map((c) => c.body.Content) };
}

export function fakeApi(overrides: Partial<AssistantApi> = {}): AssistantApi & { [k: string]: jest.Mock } {
  return {
    startChat: jest.fn(async () => ({ contactId: 'contact-1', participantToken: 'part-1', region: 'eu-west-2', verified: true, journey: 'money_hub', opener: 'I am on my Money Hub page.' })),
    startCall: jest.fn(async () => ({
      contactId: 'contact-2',
      participantToken: 'part-2',
      region: 'eu-west-2',
      verified: true,
      journey: 'banking_app',
      transcript: true,
      meeting: { MeetingId: 'm' },
      attendee: { AttendeeId: 'a', JoinToken: 'j' },
    })),
    returned: jest.fn(async () => ({ note: '', key: '' })),
    transcript: jest.fn(async () => ({ lines: [] })),
    pageMoved: jest.fn(async () => ({})),
    disputesLive: jest.fn(async () => ({ dispute: null, formSent: false })),
    disputesOpen: jest.fn(async () => ({ sessionId: 'session-1' })),
    ...overrides,
  } as any;
}

export function recordingEvents() {
  const lines: ChatLine[] = [];
  const statuses: string[] = [];
  const inputs: boolean[] = [];
  const started: StartedInfo[] = [];
  const ended: string[] = [];
  const muted: boolean[] = [];
  let activity = 0;
  const events: ConversationEvents & { muted(m: boolean): void; colleague(): void } = {
    status: (w) => statuses.push(w),
    line: (l) => lines.push(l),
    input: (on) => inputs.push(on),
    started: (i) => started.push(i),
    ended: (w) => ended.push(w),
    activity: () => {
      activity += 1;
    },
    muted: (m) => muted.push(m),
    colleague: () => statuses.push('(colleague)'),
  };
  return { events, lines, statuses, inputs, started, ended, muted, activity: () => activity };
}

export class FakeBridge implements CallBridge {
  listener: ((e: CallEvent) => void) | null = null;
  joined = 0;
  left = 0;
  mutedTo: boolean[] = [];
  async join() {
    this.joined += 1;
  }
  async setMuted(m: boolean) {
    this.mutedTo.push(m);
  }
  async leave() {
    this.left += 1;
  }
  onEvent(listener: (e: CallEvent) => void) {
    this.listener = listener;
    return () => {
      this.listener = null;
    };
  }
  fire(e: CallEvent) {
    this.listener?.(e);
  }
}

export const timers = realTimers; // jest's fake timers replace the globals these call
let n = 0;
export const uuid = () => `uuid-${++n}`;
