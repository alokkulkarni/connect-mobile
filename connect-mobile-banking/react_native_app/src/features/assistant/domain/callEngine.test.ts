// The call rules of CONTRACT.md section 5 (from talk.js), against a fake native bridge and fake time.
import { CallEngine, COULD_NOT_CONNECT, MIC_REFUSED } from './callEngine';
import { FakeBridge, fakeApi, fakeParticipant, flush, recordingEvents, timers, uuid } from './testFakes';

const FIELDS = { page: 'home', view: '', stage: '', applicationId: '', paymentId: '' };

function engine(options: { mic?: boolean; api?: ReturnType<typeof fakeApi> } = {}) {
  const bridge = new FakeBridge();
  const p = fakeParticipant();
  const api = options.api || fakeApi();
  const rec = recordingEvents();
  const call = new CallEngine({ api, participant: p.participant, bridge, microphone: { request: async () => options.mic ?? true }, timers, uuid, events: rec.events });
  return { call, bridge, p, api, rec };
}

beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

describe('CallEngine', () => {
  it('V1: asks for the microphone first; a refusal starts nothing', async () => {
    const { call, api, rec } = engine({ mic: false });
    await call.start(FIELDS);
    expect(api.startCall).not.toHaveBeenCalled();
    expect(rec.ended).toEqual([MIC_REFUSED]);
  });

  it('V2–V4: starts on the server, joins, and says connected', async () => {
    const { call, bridge, api, rec } = engine();
    await call.start(FIELDS);
    expect(api.startCall).toHaveBeenCalledWith(FIELDS);
    expect(bridge.joined).toBe(1);
    expect(rec.statuses).toEqual(['Starting your call…', 'Connecting your call…']);
    bridge.fire({ type: 'connected' });
    expect(rec.statuses.at(-1)).toBe("Connected. Speak when you're ready; what's said appears below. Headphones give the clearest call.");
  });

  it('V5: hangs up if the audio has not connected in 25 seconds', async () => {
    const { call, p, rec } = engine();
    await call.start(FIELDS);
    jest.advanceTimersByTime(25_000);
    await flush();
    expect(p.calls.map((c) => c.path)).toEqual(['connection', 'disconnect']);
    expect(p.calls[0].body).toEqual({ Type: ['CONNECTION_CREDENTIALS'] });
    expect(rec.ended).toEqual([COULD_NOT_CONNECT]);
  });

  it('V6: polls captions every 2 seconds, shows each line once, and notices a colleague', async () => {
    const lines = [
      { at: '1', who: 'assistant', text: 'Hello James.' },
      { at: '2', who: 'customer', text: 'Hi.' },
    ];
    const api = fakeApi({ transcript: jest.fn(async () => ({ lines, withPerson: true })) });
    const { call, bridge, rec } = engine({ api });
    await call.start(FIELDS);
    bridge.fire({ type: 'connected' });
    jest.advanceTimersByTime(2_000);
    await flush();
    jest.advanceTimersByTime(2_000);
    await flush();
    expect(rec.lines.map((l) => [l.who, l.text])).toEqual([
      ['them', 'Hello James.'],
      ['me', 'Hi.'],
    ]);
    expect(rec.statuses).toContain('A colleague has joined the call.');
  });

  it('V6: stops polling when captions are unavailable', async () => {
    const api = fakeApi({ transcript: jest.fn(async () => ({ lines: [], unavailable: true })) });
    const { call } = engine({ api });
    await call.start(FIELDS);
    jest.advanceTimersByTime(2_000);
    await flush();
    jest.advanceTimersByTime(10_000);
    await flush();
    expect(api.transcript).toHaveBeenCalledTimes(1);
  });

  it('V7: mutes and unmutes', async () => {
    const { call, bridge, rec } = engine();
    await call.start(FIELDS);
    await call.toggleMute();
    await call.toggleMute();
    expect(bridge.mutedTo).toEqual([true, false]);
    expect(rec.muted).toEqual([true, false]);
  });

  it('V8: hangs up through the Participant Service, then leaves the meeting', async () => {
    const { call, bridge, p, rec } = engine();
    await call.start(FIELDS);
    bridge.fire({ type: 'connected' });
    await call.hangUp();
    expect(p.calls.map((c) => [c.path, c.bearer])).toEqual([
      ['connection', 'part-2'],
      ['disconnect', 'conn-1'],
    ]);
    expect(bridge.left).toBe(1);
    expect(rec.ended).toEqual(['You ended the call.']);
  });

  it('V9: the meeting stopping after connecting ends the call; before, it could not connect', async () => {
    const first = engine();
    await first.call.start(FIELDS);
    first.bridge.fire({ type: 'connected' });
    first.bridge.fire({ type: 'stopped', code: 1 });
    expect(first.rec.ended).toEqual(['The call has ended.']);

    const second = engine();
    await second.call.start(FIELDS);
    second.bridge.fire({ type: 'stopped', code: 2 });
    expect(second.rec.ended).toEqual([COULD_NOT_CONNECT]);
  });
});
