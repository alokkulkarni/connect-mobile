// The app-wide assistant: push intents waiting for their screen, and chat and calls being off in Sample mode.
import { AssistantController, UNAVAILABLE_WORDS } from './assistantController';
import type { ScreenContext } from './screenContext';
import { FakeBridge, FakeSocket, fakeApi, fakeParticipant, flush, timers, uuid } from './testFakes';

const ctx = (screen: string, page: string, view = ''): ScreenContext => ({ screen, page, view, label: screen, launcher: '' });

function controller() {
  const api = fakeApi();
  const assistant = new AssistantController({
    api,
    participant: fakeParticipant().participant,
    sockets: () => new FakeSocket(),
    bridge: new FakeBridge(),
    microphone: { request: async () => true },
    timers,
    uuid,
  });
  return { assistant, api };
}

beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

describe('AssistantController', () => {
  it('starts a push intent’s chat only once its screen shows the asked-for context', async () => {
    const { assistant, api } = controller();
    assistant.configure(true, '');
    assistant.setContext(ctx('MoneyHub', 'money_hub', 'out'));
    assistant.autoStart('chat', (c) => c.screen === 'MoneyHub' && c.view === 'expected');
    expect(api.startChat).not.toHaveBeenCalled();
    assistant.setContext(ctx('MoneyHub', 'money_hub', 'expected'));
    await flush();
    expect(api.startChat).toHaveBeenCalledWith({ page: 'money_hub', view: 'expected', stage: '', applicationId: '', paymentId: '' });
    expect(assistant.getSnapshot().open).toBe(true);
  });

  it('starts a call for an intent whose mode is call, with the screen’s fields', async () => {
    const { assistant, api } = controller();
    assistant.configure(true, '');
    assistant.autoStart('call', (c) => c.screen === 'Cards');
    assistant.setContext({ ...ctx('Cards', 'card_dispute'), paymentId: 'TXN-2291-20261006-34900' });
    await flush();
    expect(api.startCall).toHaveBeenCalledWith(expect.objectContaining({ page: 'card_dispute', paymentId: 'TXN-2291-20261006-34900' }));
  });

  it('starts anyway after a short wait if the screen never says', async () => {
    const { assistant, api } = controller();
    assistant.configure(true, '');
    assistant.autoStart('chat', () => false);
    jest.advanceTimersByTime(6000);
    await flush();
    expect(api.startChat).toHaveBeenCalled();
  });

  it('in Sample mode opens the assistant and says why it cannot talk', () => {
    const { assistant, api } = controller();
    assistant.configure(false, '');
    assistant.autoStart('chat', () => true);
    expect(api.startChat).not.toHaveBeenCalled();
    expect(assistant.getSnapshot()).toMatchObject({ open: true, status: UNAVAILABLE_WORDS });
  });

  it('offers the screen’s draft in the chat box, unsent', async () => {
    const { assistant } = controller();
    assistant.configure(true, '');
    assistant.setContext({ ...ctx('TransactionDetail', 'money_hub', 'transactions'), draft: 'About my £32.45 payment to Amazon on 15 October: ' });
    assistant.open();
    expect(assistant.getSnapshot().draft).toBe('About my £32.45 payment to Amazon on 15 October: ');
  });

  it('a conversation already going: an intent only opens the sheet', async () => {
    const { assistant, api } = controller();
    assistant.configure(true, '');
    await assistant.startChat();
    assistant.minimise();
    assistant.autoStart('call', () => true);
    expect(api.startCall).not.toHaveBeenCalled();
    expect(assistant.getSnapshot().open).toBe(true);
  });
});
