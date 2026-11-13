// A tapped local notification goes through exactly the same handler as a push: the notification source hands its
// data to handleNotificationTap, which queues the validated intent; runIntent then navigates and starts the mode.
import notifee from '@notifee/react-native';
import { deliverTap, LocalNotificationPushSource } from '../data/LocalNotificationPushSource';
import { handleNotificationTap, intentInbox, runIntent } from './intents';

const data = { v: '1', intent: 'assist', topic: 'low_balance', mode: 'call', paymentId: '', transactionId: '', view: '' };

function drain() {
  const taken = [];
  let next = intentInbox.take();
  while (next) {
    taken.push(next);
    next = intentInbox.take();
  }
  return taken;
}

describe('notification taps', () => {
  beforeEach(() => drain());

  it('routes a local notification tap through the push handler, once per notification', async () => {
    const source = new LocalNotificationPushSource();
    const stop = await source.start(handleNotificationTap);
    deliverTap('n-1', data);
    deliverTap('n-1', data); // iOS can report the launching tap twice
    const intents = drain();
    expect(intents).toHaveLength(1);
    expect(intents[0]).toEqual({ topic: 'low_balance', mode: 'call', destination: { screen: 'money_hub', view: 'expected' }, autoStart: true });
    stop();
  });

  it('keeps a tap that arrives before anything listens (a background tap while the app wakes)', async () => {
    deliverTap('n-2', { ...data, topic: 'salary_in', mode: 'chat' });
    const source = new LocalNotificationPushSource();
    const stop = await source.start(handleNotificationTap);
    expect(drain().map((i) => i.topic)).toEqual(['salary_in']);
    stop();
  });

  it('runs the intent: the screen first, then the mode once that screen says where the customer is', () => {
    const navigate = jest.fn();
    const autoStart = jest.fn();
    const intent = handleNotificationTap({ ...data, topic: 'unusual_payment', mode: 'chat', paymentId: 'TXN-2291-20261006-34900' });
    runIntent(intent, { navigate } as never, { autoStart } as never);
    expect(navigate).toHaveBeenCalledWith('Tabs', expect.objectContaining({ screen: 'Cards', params: expect.objectContaining({ paymentId: 'TXN-2291-20261006-34900' }) }));
    expect(autoStart).toHaveBeenCalledWith('chat', expect.any(Function));
    const matches = autoStart.mock.calls[0][1];
    expect(matches({ screen: 'Cards', page: 'card_dispute', paymentId: 'TXN-2291-20261006-34900' })).toBe(true);
    expect(matches({ screen: 'Home', page: 'home' })).toBe(false);
  });

  it('schedules a sample 5 seconds ahead with its push data', async () => {
    const source = new LocalNotificationPushSource();
    const spy = jest.spyOn(notifee, 'createTriggerNotification');
    const before = Date.now();
    await source.schedule({ id: 'low_balance', title: 'Your balance is getting low', body: 'Tap to call us.', data }, 5000);
    const [notification, trigger] = spy.mock.calls[0] as [any, any];
    expect(notification.data).toEqual(data);
    expect(trigger.timestamp).toBeGreaterThanOrEqual(before + 5000);
  });
});
