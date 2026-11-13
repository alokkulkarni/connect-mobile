import { layout, plain } from './messageLayout';
import { day, gbp, initials, longDay, monthName, pounds, signed, tidyMerchant } from './money';

describe('money', () => {
  it('writes pounds as the web app does', () => {
    expect(gbp(1234.5)).toBe('£1,234.50');
    expect(gbp(-32.45)).toBe('−£32.45');
    expect(gbp('349.00')).toBe('£349.00');
    expect(gbp(0)).toBe('£0.00');
    expect(gbp(-0.001)).toBe('£0.00');
    expect(pounds(1050.4)).toBe('£1,050');
    expect(signed(3150, true)).toBe('+£3,150.00');
    expect(signed(-32.45, false)).toBe('−£32.45');
  });

  it('writes dates as the web app does', () => {
    expect(day('2026-10-15')).toBe('15 Oct');
    expect(longDay('2026-10-15')).toBe('Thursday 15 October 2026');
    expect(monthName('2026-07')).toBe('July 2026');
    expect(monthName('2026-07', true)).toBe('Jul');
  });

  it('tidies merchant names and makes tile initials', () => {
    expect(tidyMerchant('ELECTROWORLD ONLINE')).toBe('Electroworld Online');
    expect(initials('PRET A MANGER')).toBe('PA');
    expect(initials('Amazon')).toBe('AM');
  });
});

describe('message layout', () => {
  it('splits sentences, ends on the question and shows emphasis as plain text', () => {
    expect(plain('You spent **£300** on shopping.')).toBe('You spent £300 on shopping.');
    const blocks = layout('You spent £300 on shopping. It was more than usual. Want a plan?');
    expect(blocks.map((b) => b.kind)).toEqual(['line', 'line', 'ask']);
  });

  it('turns bullet lines and amount lists into lists', () => {
    expect(layout('The biggest three:\n- Shopping £300\n- Holidays £296\n- Eating out £161')[0]).toEqual({
      kind: 'list',
      lead: 'The biggest three:',
      ordered: false,
      items: ['Shopping £300', 'Holidays £296', 'Eating out £161'],
    });
    const list = layout('The biggest three are shopping at £300, holidays at £296, and eating out at £161.')[0];
    expect(list).toMatchObject({ kind: 'list', items: ['Shopping: £300', 'Holidays: £296', 'Eating out: £161'] });
  });
});
