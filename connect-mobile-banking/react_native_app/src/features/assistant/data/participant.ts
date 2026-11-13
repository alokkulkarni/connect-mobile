// The Amazon Connect Participant Service over HTTPS, and its WebSocket. Plain HTTPS with the participant or
// connection token in X-Amz-Bearer: no AWS SDK, no AWS credentials. Tokens never reach a log.
import { participantBase } from '../../../core/config/appConfig';
import type { ChatSocket, ParticipantPort, SocketFactory } from '../domain/ports';

export class ParticipantHttpClient implements ParticipantPort {
  constructor(private readonly fetchImpl: typeof fetch = fetch) {}

  async post<T = any>(region: string, path: string, bearer: string, body: Record<string, unknown>): Promise<T> {
    const response = await this.fetchImpl(`${participantBase(region)}/${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'X-Amz-Bearer': bearer },
      body: JSON.stringify(body),
    });
    if (!response.ok) {
      // Connect's own reason, in development builds only (it never contains a token).
      if (__DEV__) {
        const reason = await response.json().then((j: any) => j.Message || j.message || '').catch(() => '');
        console.warn(`Connect participant ${path} failed: ${response.status} ${reason}`);
      }
      throw new Error(`We couldn't connect the conversation (${response.status}). Please try again.`);
    }
    return response.json().catch(() => ({})) as Promise<T>;
  }
}

export const webSocketFactory: SocketFactory = (url: string): ChatSocket => {
  if (!url.startsWith('wss://')) throw new Error("We couldn't connect the conversation. Please try again.");
  const ws = new WebSocket(url);
  const socket: ChatSocket = {
    send: (text) => {
      if (ws.readyState === WebSocket.OPEN) ws.send(text);
    },
    close: () => ws.close(),
    onOpen: () => {},
    onMessage: () => {},
    onClose: () => {},
  };
  ws.onopen = () => socket.onOpen();
  ws.onmessage = (event) => socket.onMessage(String(event.data));
  ws.onclose = () => socket.onClose();
  ws.onerror = () => {
    /* a close follows */
  };
  return socket;
};
