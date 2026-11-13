// What the assistant needs from the outside world, as interfaces. data/ implements them over HTTPS, a WebSocket and
// the native call module; tests implement them with fakes.
import type { PageFields } from './screenContext';

export type ChatStart = { contactId: string; participantToken: string; region: string; verified: boolean; journey: string; opener: string };

export type CallStart = {
  contactId: string;
  participantToken: string;
  region: string;
  verified: boolean;
  journey: string;
  transcript: boolean;
  meeting: Record<string, unknown>;
  attendee: Record<string, unknown>;
};

export type TranscriptReply = { lines?: { at: string; who: string; text: string }[]; ended?: boolean; withPerson?: boolean; unavailable?: boolean };

// The banking app's own contact routes (CONTRACT.md section 2).
export interface AssistantApi {
  startChat(fields: PageFields): Promise<ChatStart>;
  startCall(fields: PageFields): Promise<CallStart>;
  returned(contactId: string): Promise<{ note: string; key: string }>;
  transcript(contactId: string): Promise<TranscriptReply>;
  pageMoved(contactId: string, fields: PageFields): Promise<unknown>;
  disputesLive(contactId: string): Promise<{ dispute: { disputeId: string } | null; formSent: boolean }>;
  disputesOpen(contactId: string, disputeId: string): Promise<{ sessionId: string }>;
}

// The Amazon Connect Participant Service: POST <base>/<path> with X-Amz-Bearer. Throws an Error whose message is
// written for the customer.
export interface ParticipantPort {
  post<T = any>(region: string, path: string, bearer: string, body: Record<string, unknown>): Promise<T>;
}

export interface ChatSocket {
  send(text: string): void;
  close(): void;
  onOpen: () => void;
  onMessage: (text: string) => void;
  onClose: () => void;
}

export type SocketFactory = (url: string) => ChatSocket;

export type CallEvent =
  | { type: 'connected' }
  | { type: 'stopped'; code: number }
  | { type: 'muted'; muted: boolean }
  | { type: 'error'; message: string };

// The native call module (Amazon Chime SDK): join, mute, leave. Nothing else crosses.
export interface CallBridge {
  join(meeting: Record<string, unknown>, attendee: Record<string, unknown>): Promise<void>;
  setMuted(muted: boolean): Promise<void>;
  leave(): Promise<void>;
  onEvent(listener: (event: CallEvent) => void): () => void;
}

export interface Microphone {
  request(): Promise<boolean>;
}
