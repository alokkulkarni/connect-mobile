// The Notifications screen's five samples, built from the sample customer's own data, and a tapped notification
// going through the same handler as a push.
import { fixtures } from '../../../core/fixtures';
import type { CardsView } from '../../cards/domain/cards';
import type { MoneyHub } from '../../money_hub/domain/moneyHub';
import type { Transaction } from '../../transactions/domain/transactions';
import { parseAssistIntent } from './intents';
import { buildSamples } from './samples';

const input = {
  cards: fixtures.appCards as CardsView,
  hub: fixtures.hub as unknown as MoneyHub,
  transactions: fixtures.transactions.slice(0, 25) as Transaction[],
};

describe('buildSamples', () => {
  const samples = buildSamples(input);

  it('builds the five samples with their fixed modes', () => {
    expect(samples.map((s) => [s.data.topic, s.data.mode])).toEqual([
      ['unusual_payment', 'chat'],
      ['low_balance', 'call'],
      ['salary_in', 'chat'],
      ['savings_goal', 'call'],
      ['large_payment', 'chat'],
    ]);
  });

  it('carries only strings, version 1, intent assist', () => {
    for (const sample of samples) {
      expect(Object.values(sample.data).every((v) => typeof v === 'string')).toBe(true);
      expect(sample.data).toMatchObject({ v: '1', intent: 'assist' });
    }
  });

  it('names the largest credit card payment and the largest payment out by valid IDs', () => {
    const unusual = samples.find((s) => s.id === 'unusual_payment')!;
    expect(unusual.data.paymentId).toBe('TXN-2291-20261004-61200');
    expect(unusual.data.paymentId).toMatch(/^TXN-\d{4}-\d{8}-\d{1,9}$/);
    expect(unusual.body).toBe('£612.00 at Sunshine Villas Booking on your credit card ending 2291. Tap to chat with us.');
    expect(unusual.body.endsWith('Tap to chat with us.')).toBe(true);

    const large = samples.find((s) => s.id === 'large_payment')!;
    const largest = [...input.transactions].filter((t) => t.amount < 0).sort((a, b) => a.amount - b.amount)[0];
    expect(large.data.transactionId).toBe(largest.transactionId);
    expect(large.data.transactionId).toMatch(/^MH-\d{3}-\d{8}-\d{4}$/);
  });

  it('words the call samples as calls', () => {
    expect(samples.find((s) => s.id === 'low_balance')!.body.endsWith('Tap to call us.')).toBe(true);
    expect(samples.find((s) => s.id === 'savings_goal')!.title).toBe('Your Holiday in Japan goal');
  });

  it('turns each into an intent that starts the right conversation on the right screen', () => {
    const intents = samples.map((s) => parseAssistIntent(s.data));
    expect(intents.map((i) => [i.destination.screen, i.mode, i.autoStart])).toEqual([
      ['cards', 'chat', true],
      ['money_hub', 'call', true],
      ['money_hub', 'chat', true],
      ['money_hub', 'call', true],
      ['transaction', 'chat', true],
    ]);
  });

  it('leaves out the goal sample when there are no goals', () => {
    const none = buildSamples({ ...input, hub: { ...input.hub, goals: [] } });
    expect(none.map((s) => s.id)).not.toContain('savings_goal');
    expect(none).toHaveLength(4);
  });
});
