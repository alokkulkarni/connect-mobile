// The chat rules of CONTRACT.md section 4 (from talk.js), against fake ports and fake time.
import { ChatEngine, disputeFormLink, isReturnNote } from './chatEngine';
import { FakeSocket, fakeApi, fakeParticipant, flush, recordingEvents, timers, uuid } from './testFakes';

const FIELDS = { page: 'money_hub', view: 'out', stage: '', applicationId: '', paymentId: '' };

async function started(options: { transcript?: Record<string, unknown>[]; api?: ReturnType<typeof fakeApi>; pagesUrl?: string } = {}) {
  const socket = new FakeSocket();
  const sockets: FakeSocket[] = [];
  const p = fakeParticipant(options.transcript);
  const api = options.api || fakeApi();
  const rec = recordingEvents();
  const engine = new ChatEngine({
    api,
    participant: p.participant,
    sockets: () => {
      const s = sockets.length ? new FakeSocket() : socket;
      sockets.push(s);
      return s;
    },
    timers,
    uuid,
    disputePagesUrl: () => options.pagesUrl || '',
    events: rec.events,
  });
  await engine.start(FIELDS);
  socket.onOpen();
  await flush();
  return { engine, socket, sockets, p, api, rec };
}

beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

describe('ChatEngine', () => {
  it('C1–C4: starts on the server, joins with WEBSOCKET and CONNECTION_CREDENTIALS, subscribes, reads the transcript', async () => {
    const { p, socket, api, rec } = await started();
    expect(api.startChat).toHaveBeenCalledWith(FIELDS);
    expect(p.calls[0]).toEqual({ path: 'connection', bearer: 'part-1', body: { Type: ['WEBSOCKET', 'CONNECTION_CREDENTIALS'] } });
    expect(JSON.parse(socket.sent[0])).toEqual({ topic: 'aws/subscribe', content: { topics: ['aws/chat'] } });
    expect(p.calls[1]).toEqual({ path: 'transcript', bearer: 'conn-1', body: { MaxResults: 100, ScanDirection: 'BACKWARD', SortOrder: 'ASCENDING' } });
    expect(rec.statuses).toEqual(['Connecting you…', 'Connecting you to our assistant…']);
    expect(rec.started).toEqual([{ kind: 'chat', journey: 'money_hub', contactId: 'contact-1' }]);
  });

  it('C3: sends a heartbeat every 10 seconds', async () => {
    const { socket } = await started();
    jest.advanceTimersByTime(30_000);
    expect(socket.sent.filter((s) => s.includes('aws/heartbeat'))).toHaveLength(3);
  });

  it('C7: sends the opener once, on the first message from the assistant side (even a blank one), then enables typing', async () => {
    const { socket, p, rec } = await started();
    expect(rec.inputs.at(-1)).toBe(false);
    socket.item({ Id: '1', Type: 'MESSAGE', ParticipantRole: 'SYSTEM', Content: ' ' });
    socket.item({ Id: '2', Type: 'MESSAGE', ParticipantRole: 'AGENT', Content: 'Hello James.' });
    await flush();
    expect(p.messages()).toEqual(['I am on my Money Hub page.']);
    expect(rec.inputs.at(-1)).toBe(true);
    expect(rec.statuses.at(-1)).toBe('Connected.');
    expect(rec.lines.map((l) => [l.who, l.text])).toEqual([['them', 'Hello James.']]);
  });

  it('C7: sends the opener after 20 seconds if the assistant says nothing', async () => {
    const { p, rec } = await started();
    jest.advanceTimersByTime(19_999);
    expect(p.messages()).toEqual([]);
    jest.advanceTimersByTime(1);
    await flush();
    expect(p.messages()).toEqual(['I am on my Money Hub page.']);
    expect(rec.inputs.at(-1)).toBe(true);
  });

  it('C5: shows each item once, whether it came in the transcript or on the socket', async () => {
    const hello = { Id: 'h', Type: 'MESSAGE', ParticipantRole: 'AGENT', Content: 'Hello.' };
    const { socket, rec } = await started({ transcript: [hello] });
    socket.item(hello);
    socket.onMessage('not json');
    socket.onMessage(JSON.stringify({ topic: 'aws/other', content: '{}' }));
    expect(rec.lines).toHaveLength(1);
  });

  it('C6: never shows the return notes the app sends ARIA, and shows the customer as "me" in plain text', async () => {
    const { socket, rec } = await started();
    socket.item({ Id: 'r', Type: 'MESSAGE', ParticipantRole: 'CUSTOMER', Content: 'Back from card dispute: all done' });
    socket.item({ Id: 'c', Type: 'MESSAGE', ParticipantRole: 'CUSTOMER', Content: 'Where does my **money** go?' });
    expect(rec.lines.map((l) => [l.who, l.text])).toEqual([['me', 'Where does my money go?']]);
    expect(isReturnNote('  Back from mortgage application: x')).toBe(true);
  });

  it('C8: after the opener, a blank assistant message sends ARIA the return note once per key', async () => {
    const api = fakeApi({ returned: jest.fn(async () => ({ note: 'Back from card dispute: They want help with something else.', key: 'k1' })) });
    const { socket, p } = await started({ api });
    socket.item({ Id: '1', Type: 'MESSAGE', ParticipantRole: 'SYSTEM', Content: '' }); // opener
    await flush();
    socket.item({ Id: '2', Type: 'MESSAGE', ParticipantRole: 'SYSTEM', Content: '' }); // bot block started again
    await flush();
    socket.item({ Id: '3', Type: 'MESSAGE', ParticipantRole: 'SYSTEM', Content: '' }); // again, same return
    await flush();
    expect(api.returned).toHaveBeenCalledTimes(2);
    expect(p.messages()).toEqual(['I am on my Money Hub page.', 'Back from card dispute: They want help with something else.']);
  });

  it('C9: finds the dispute form link the assistant posts, exactly', async () => {
    const link = 'https://disputes.example/form#k=Abcdefghijklmnop1234';
    const { socket, rec } = await started({ pagesUrl: 'https://disputes.example' });
    socket.item({ Id: 'd', Type: 'MESSAGE', ParticipantRole: 'AGENT', Content: `Here is your form: ${link} . Fill it in with me.` });
    expect(rec.lines[0].formLink).toBe(link);
    expect(disputeFormLink('see https://evil.example/#k=Abcdefghijklmnop1234', 'https://disputes.example')).toBe('');
    expect(disputeFormLink(`see ${link}`, '')).toBe('');
  });

  it('C10: the chat-ended event ends the chat', async () => {
    const { socket, rec, engine } = await started();
    socket.item({ Id: 'e', Type: 'EVENT', ContentType: 'application/vnd.amazonaws.connect.event.chat.ended' });
    expect(rec.ended).toEqual(['The chat has ended.']);
    expect(engine.active).toBe(false);
    expect(socket.closed).toBe(true);
  });

  it('C11, C12: sends messages with a ClientToken and leaves with disconnect', async () => {
    const { engine, p, rec } = await started();
    await engine.send('  Hello  ');
    expect(p.calls.at(-1)).toMatchObject({ path: 'message', bearer: 'conn-1', body: { ContentType: 'text/plain', Content: 'Hello' } });
    expect(p.calls.at(-1)!.body.ClientToken).toMatch(/^uuid-/);
    await engine.end();
    expect(p.calls.at(-1)).toMatchObject({ path: 'disconnect', bearer: 'conn-1' });
    expect(rec.ended).toEqual(['You ended the chat.']);
  });

  it('C13: the background never ends a chat; back in the foreground it rejoins', async () => {
    const { engine, socket, sockets, p, rec } = await started();
    await engine.setForeground(false);
    socket.onClose();
    expect(rec.ended).toEqual([]);
    await engine.setForeground(true);
    await flush();
    expect(p.calls.filter((c) => c.path === 'connection')).toHaveLength(2);
    expect(sockets).toHaveLength(2);
    expect(engine.active).toBe(true);
  });

  it('C10: the socket closing in the foreground ends the chat', async () => {
    const { socket, rec } = await started();
    socket.onClose();
    expect(rec.ended).toEqual(['The chat has ended.']);
  });

  it('says what went wrong when the contact cannot start', async () => {
    const api = fakeApi({ startChat: jest.fn(async () => Promise.reject(new Error("We couldn't connect you just now. Try again in a minute."))) });
    const rec = recordingEvents();
    const engine = new ChatEngine({ api, participant: fakeParticipant().participant, sockets: () => new FakeSocket(), timers, uuid, disputePagesUrl: () => '', events: rec.events });
    await engine.start(FIELDS);
    expect(rec.ended).toEqual(["We couldn't connect you just now. Try again in a minute."]);
  });
});
