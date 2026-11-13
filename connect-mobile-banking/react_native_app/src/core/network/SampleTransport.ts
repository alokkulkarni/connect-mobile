// Sample mode: the backend's own replies for the sample customer (fixtures/), with the write routes kept in memory
// for the session. Chat and calls are off (`talk` is false), as the web app hides its assistant when they aren't
// set up; the contact routes answer as the backend does then.
import { fixtures } from '../fixtures';
import { TRANSACTIONS_PAGE_SIZE } from '../config/appConfig';
import { ApiError, ApiTransport, Json } from './ApiTransport';

type Row = Record<string, any>;
const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value));
const str = (body: Json, name: string) => (typeof body[name] === 'string' ? (body[name] as string).trim() : '');

export class SampleTransport implements ApiTransport {
  readonly mode = 'sample' as const;
  private readonly transactions: Row[] = clone(fixtures.transactions);
  private readonly hub: Row = clone(fixtures.hub);
  private readonly disputes: Row[] = clone(fixtures.disputes.disputes);

  async post<T = Json>(route: string, body: Json = {}): Promise<T> {
    return this.answer(route, body) as T;
  }

  private answer(route: string, body: Json): unknown {
    switch (route) {
      case 'app/home':
        return { ...clone(fixtures.appHome), talk: false, disputePagesUrl: '' };
      case 'app/accounts':
        return clone(str(body, 'account') === 'savings' ? fixtures.accountsSavings : fixtures.accountsCurrent);
      case 'app/cards':
        return clone(fixtures.appCards);
      case 'hub':
        return { ...clone(this.hub), talk: false };
      case 'transactions':
        return this.list(body);
      case 'recategorise':
        return this.recategorise(str(body, 'transactionId'), str(body, 'category'));
      case 'goal':
        return this.saveGoal(body);
      case 'goal/delete':
        this.hub.goals = (this.hub.goals as Row[]).filter((g) => g.name !== str(body, 'name'));
        return { goals: clone(this.hub.goals) };
      case 'disputes':
        return { disputes: clone(this.disputes) };
      case 'disputes/submit':
        return this.submit(str(body, 'disputeId'));
      case 'mortgage/config':
        return clone(fixtures.mortgageConfig);
      default:
        if (route.startsWith('contact/') || route.startsWith('disputes/')) {
          throw new ApiError('talk_unavailable', "Calls and chats aren't set up for this app yet.", 503);
        }
        throw new ApiError('not_found', 'Not found', 404);
    }
  }

  private list(body: Json) {
    const from = str(body, 'from');
    const to = str(body, 'to');
    const category = str(body, 'category');
    const direction = str(body, 'direction');
    const merchant = str(body, 'merchant').toLowerCase();
    const rows = this.transactions.filter(
      (t) =>
        (!from || t.date >= from) &&
        (!to || t.date <= to) &&
        (!category || t.category === category) &&
        (!direction || t.direction === direction) &&
        (!merchant || String(t.merchant).toLowerCase().includes(merchant)),
    );
    const pages = Math.max(1, Math.ceil(rows.length / TRANSACTIONS_PAGE_SIZE));
    const page = Math.max(1, Number(body.page) || 1);
    return {
      transactions: clone(rows.slice((page - 1) * TRANSACTIONS_PAGE_SIZE, page * TRANSACTIONS_PAGE_SIZE)),
      page,
      totalPages: pages,
      total: rows.length,
      hasMore: page < pages,
    };
  }

  private recategorise(id: string, category: string) {
    const row = this.transactions.find((t) => t.transactionId === id);
    if (!row) throw new ApiError('transaction_not_found', "That transaction isn't on this account.", 404);
    const choices = this.hub.choices as { in: Row[]; out: Row[] };
    const side = row.direction === 'in' ? choices.in : choices.out;
    const chosen = side.find((c) => c.category === category);
    if (!chosen) {
      throw new ApiError('wrong_direction', 'Money in can only go in a money-in category, and money out in a money-out one.', 400);
    }
    Object.assign(row, { category, categoryWords: chosen.words, recategorised: true });
    return { transaction: clone(row) };
  }

  private saveGoal(body: Json) {
    const name = str(body, 'name');
    const target = Number(body.target);
    const saved = Number(body.saved) || 0;
    const byDate = str(body, 'byDate');
    if (!name || !(target > 0) || !/^\d{4}-\d{2}-\d{2}$/.test(byDate)) {
      throw new ApiError('bad_request', 'Give the goal a name, an amount and a date.', 400);
    }
    const months = Math.max(1, monthsUntil(byDate));
    const needed = Math.round(((target - saved) / months) * 100) / 100;
    const goal = { name, target, byDate, saved, neededPerMonth: needed, onTrack: needed <= 200, plan: { months, neededPerMonth: needed, onTrack: needed <= 200, targetDateWords: byDate, changes: [] } };
    this.hub.goals = [...(this.hub.goals as Row[]).filter((g) => g.name !== name), goal];
    return { goal: clone(goal), plan: clone(goal.plan) };
  }

  private submit(id: string) {
    const dispute = this.disputes.find((d) => d.disputeId === id);
    if (!dispute) throw new ApiError('not_found', "That dispute isn't available.", 404);
    if (!dispute.canSubmit) throw new ApiError('incomplete', 'This dispute still needs some details before it can be sent.', 400);
    Object.assign(dispute, { status: 'submitted', statusWords: 'Submitted', canSubmit: false });
    return { dispute: clone(dispute) };
  }
}

// Whole months from the sample data's own date (15 October 2026) to a goal's date.
function monthsUntil(day: string): number {
  const [y, m] = day.split('-').map(Number);
  return (y - 2026) * 12 + (m - 10);
}
