import { contextMatches, parseAssistIntent, screenOf } from './intents';

const base = { v: '1', intent: 'assist', mode: 'chat', paymentId: '', transactionId: '', view: '' };

describe('parseAssistIntent', () => {
  it('opens Home for anything that is not version 1', () => {
    expect(parseAssistIntent({ ...base, v: '2', topic: 'low_balance' })).toEqual({ topic: '', mode: 'chat', destination: { screen: 'home' }, autoStart: false });
    expect(parseAssistIntent(null).destination).toEqual({ screen: 'home' });
    expect(parseAssistIntent('nonsense').destination).toEqual({ screen: 'home' });
  });

  it.each([
    ['money_out', { screen: 'money_hub', view: 'out' }],
    ['spending_insight', { screen: 'money_hub', view: 'out' }],
    ['money_in', { screen: 'money_hub', view: 'in' }],
    ['salary_in', { screen: 'money_hub', view: 'in' }],
    ['low_balance', { screen: 'money_hub', view: 'expected' }],
    ['bill_due', { screen: 'money_hub', view: 'expected' }],
    ['savings_goal', { screen: 'money_hub', view: 'goals' }],
    ['transfer', { screen: 'accounts' }],
    ['dispute_update', { screen: 'cards', tab: 'disputes' }],
    ['unusual_payment', { screen: 'cards' }],
    ['large_payment', { screen: 'money_hub', view: 'transactions' }],
  ])('sends %s to its screen and starts a conversation', (topic, destination) => {
    const intent = parseAssistIntent({ ...base, topic });
    expect(intent.destination).toEqual(destination);
    expect(intent.autoStart).toBe(true);
  });

  it('only opens the screen for topics that are not about money, and for intent "open"', () => {
    expect(parseAssistIntent({ ...base, topic: 'mortgage' })).toMatchObject({ destination: { screen: 'mortgages' }, autoStart: false });
    expect(parseAssistIntent({ ...base, topic: 'marketing' })).toMatchObject({ destination: { screen: 'home' }, autoStart: false });
    expect(parseAssistIntent({ ...base, intent: 'open', topic: 'low_balance' })).toMatchObject({ destination: { screen: 'money_hub', view: 'expected' }, autoStart: false });
  });

  it('keeps a well-formed payment or transaction, and drops malformed ones', () => {
    expect(parseAssistIntent({ ...base, topic: 'unusual_payment', paymentId: 'TXN-2291-20261006-34900' }).destination).toEqual({ screen: 'cards', paymentId: 'TXN-2291-20261006-34900' });
    expect(parseAssistIntent({ ...base, topic: 'unusual_payment', paymentId: 'TXN-<script>' }).destination).toEqual({ screen: 'cards' });
    expect(parseAssistIntent({ ...base, topic: 'large_payment', transactionId: 'MH-001-20261015-0332' }).destination).toEqual({ screen: 'transaction', transactionId: 'MH-001-20261015-0332' });
    expect(parseAssistIntent({ ...base, topic: 'large_payment', transactionId: 'MH-1' }).destination).toEqual({ screen: 'money_hub', view: 'transactions' });
  });

  it('lets a valid view override the topic tab, and drops an unknown one', () => {
    expect(parseAssistIntent({ ...base, topic: 'low_balance', view: 'goals' }).destination).toEqual({ screen: 'money_hub', view: 'goals' });
    expect(parseAssistIntent({ ...base, topic: 'low_balance', view: 'admin' }).destination).toEqual({ screen: 'money_hub', view: 'expected' });
  });

  it('defaults the mode to chat and accepts call', () => {
    expect(parseAssistIntent({ ...base, topic: 'low_balance', mode: 'video' }).mode).toBe('chat');
    expect(parseAssistIntent({ ...base, topic: 'low_balance', mode: 'call' }).mode).toBe('call');
  });

  it('ignores fields it does not know, such as a customer ID', () => {
    const intent = parseAssistIntent({ ...base, topic: 'salary_in', customerId: 'CUST-999', amount: '1000000' });
    expect(intent).toEqual({ topic: 'salary_in', mode: 'chat', destination: { screen: 'money_hub', view: 'in' }, autoStart: true });
  });
});

describe('contextMatches', () => {
  it('waits for the Money Hub on the asked-for tab', () => {
    const matches = contextMatches({ screen: 'money_hub', view: 'expected' });
    expect(screenOf({ screen: 'money_hub', view: 'expected' })).toBe('MoneyHub');
    expect(matches({ screen: 'MoneyHub', page: 'money_hub', view: 'out' })).toBe(false);
    expect(matches({ screen: 'MoneyHub', page: 'money_hub', view: 'expected' })).toBe(true);
    expect(matches({ screen: 'Home', page: 'home' })).toBe(false);
  });

  it('waits for Cards with the payment chosen, or without one when it is not the customer’s', () => {
    const matches = contextMatches({ screen: 'cards', paymentId: 'TXN-2291-20261006-34900' });
    expect(matches({ screen: 'Cards', page: 'card_dispute', paymentId: 'TXN-2291-20261006-34900' })).toBe(true);
    expect(matches({ screen: 'Cards', page: 'card_dispute', paymentId: 'TXN-4821-20261015-3245' })).toBe(false);
    expect(matches({ screen: 'Cards', page: 'cards' })).toBe(true);
  });
});
