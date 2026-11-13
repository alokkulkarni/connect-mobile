// Following the customer during a conversation (CONTRACT.md section 6): page moves and the dispute watch.
import { DisputeWatch, PageMoveTracker } from './following';
import type { ScreenContext } from './screenContext';
import { flush, timers } from './testFakes';

const ctx = (page: string, view = '', paymentId = ''): ScreenContext => ({ page, view, paymentId, label: page, launcher: '', screen: page });

beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

describe('PageMoveTracker', () => {
  function tracker() {
    let current = ctx('home');
    const report = jest.fn(async () => ({}));
    const t = new PageMoveTracker(timers, 1500, () => current, report);
    const go = (next: ScreenContext) => {
      current = next;
      t.changed();
    };
    return { t, report, go };
  }

  it('tells the assistant about a screen the customer stays on for 1.5 seconds', async () => {
    const { t, report, go } = tracker();
    t.begin('c1', ctx('home'));
    go(ctx('money_hub', 'out'));
    jest.advanceTimersByTime(1499);
    expect(report).not.toHaveBeenCalled();
    jest.advanceTimersByTime(1);
    await flush();
    expect(report).toHaveBeenCalledWith('c1', { page: 'money_hub', view: 'out', stage: '', applicationId: '', paymentId: '' });
  });

  it('never tells the screen the conversation started on, and never the same one twice in a row', async () => {
    const { t, report, go } = tracker();
    t.begin('c1', ctx('cards'));
    go(ctx('cards'));
    jest.advanceTimersByTime(2000);
    go(ctx('money_hub', 'in'));
    jest.advanceTimersByTime(2000);
    go(ctx('money_hub', 'in'));
    jest.advanceTimersByTime(2000);
    await flush();
    expect(report).toHaveBeenCalledTimes(1);
  });

  it('only the screen the customer settles on: quick moves in between are not told', async () => {
    const { t, report, go } = tracker();
    t.begin('c1', ctx('home'));
    go(ctx('accounts'));
    jest.advanceTimersByTime(500);
    go(ctx('cards'));
    jest.advanceTimersByTime(500);
    go(ctx('card_dispute', '', 'TXN-4821-20261015-3245'));
    jest.advanceTimersByTime(1500);
    await flush();
    expect(report).toHaveBeenCalledTimes(1);
    expect(report.mock.calls[0]).toEqual(['c1', expect.objectContaining({ page: 'card_dispute', paymentId: 'TXN-4821-20261015-3245' })]);
  });

  it('says nothing outside a conversation, or on a screen with no assistant of its own', async () => {
    const { t, report, go } = tracker();
    go(ctx('cards'));
    jest.advanceTimersByTime(2000);
    t.begin('c1', ctx('home'));
    go({ label: 'Form', launcher: '', screen: 'Form' });
    jest.advanceTimersByTime(2000);
    t.end();
    go(ctx('help'));
    jest.advanceTimersByTime(2000);
    await flush();
    expect(report).not.toHaveBeenCalled();
  });
});

describe('DisputeWatch', () => {
  it('opens the form once per conversation, as soon as it is sent', async () => {
    let sent = false;
    const api = { live: jest.fn(async () => ({ dispute: sent ? { disputeId: 'DSP-1' } : null, formSent: sent })), open: jest.fn(async () => ({ sessionId: 'S-1' })) };
    const opened = jest.fn();
    const watch = new DisputeWatch(timers, 4000, api, opened);
    watch.begin('c1');
    jest.advanceTimersByTime(4000);
    await flush();
    expect(api.live).toHaveBeenCalledTimes(1);
    sent = true;
    jest.advanceTimersByTime(4000);
    await flush();
    jest.advanceTimersByTime(12_000);
    await flush();
    expect(api.open).toHaveBeenCalledTimes(1);
    expect(api.open).toHaveBeenCalledWith('c1', 'DSP-1');
    expect(opened).toHaveBeenCalledWith('S-1');
    expect(api.live).toHaveBeenCalledTimes(2);
  });

  it('stops once the form was opened from the chat’s own link', async () => {
    const api = { live: jest.fn(async () => ({ dispute: { disputeId: 'DSP-1' }, formSent: true })), open: jest.fn(async () => ({ sessionId: 'S-1' })) };
    const watch = new DisputeWatch(timers, 4000, api, jest.fn());
    watch.begin('c1');
    watch.markOpened();
    jest.advanceTimersByTime(8000);
    await flush();
    expect(api.live).not.toHaveBeenCalled();
  });

  it('keeps looking when disputes are not set up', async () => {
    const api = { live: jest.fn(async () => Promise.reject(new Error('503'))), open: jest.fn() };
    const watch = new DisputeWatch(timers, 4000, api, jest.fn());
    watch.begin('c1');
    for (let i = 0; i < 3; i++) {
      jest.advanceTimersByTime(4000);
      await flush();
    }
    expect(api.live).toHaveBeenCalledTimes(3);
    watch.end();
  });
});
