// Following the customer during a conversation (CONTRACT.md section 6, from web/app.js):
//   PageMoveTracker  a new screen (or Money Hub tab, or chosen payment) the customer stays on for 1.5 s is told to
//                    the assistant; never the one the conversation started on, never the same one twice in a row
//   DisputeWatch     every 4 s, has the dispute assistant sent its form? Once per conversation, open it
import type { TimerHandle, Timers } from '../../../core/util/timers';
import { PageFields, ScreenContext, pageFields, pageKey } from './screenContext';

export class PageMoveTracker {
  private contactId = '';
  private key = '';
  private timer: TimerHandle | null = null;

  constructor(
    private readonly timers: Timers,
    private readonly settleMs: number,
    private readonly current: () => ScreenContext,
    private readonly report: (contactId: string, fields: PageFields) => Promise<unknown>,
  ) {}

  begin(contactId: string, where: ScreenContext): void {
    this.end();
    this.contactId = contactId;
    this.key = pageKey(where); // where it started: nothing to tell yet
  }

  changed(): void {
    if (!this.contactId) return;
    this.timers.clearTimeout(this.timer);
    const contactId = this.contactId;
    this.timer = this.timers.setTimeout(async () => {
      const now = this.current();
      if (this.contactId !== contactId || !now.page || pageKey(now) === this.key) return;
      this.key = pageKey(now);
      try {
        await this.report(contactId, pageFields(now));
      } catch {
        /* the conversation carries on; the next move tries again */
      }
    }, this.settleMs);
  }

  end(): void {
    this.timers.clearTimeout(this.timer);
    this.timer = null;
    this.contactId = '';
  }
}

export type DisputeApi = {
  live(contactId: string): Promise<{ dispute: { disputeId: string } | null; formSent: boolean }>;
  open(contactId: string, disputeId: string): Promise<{ sessionId: string }>;
};

type Watch = { contactId: string; timer: TimerHandle | null; opened: boolean };

export class DisputeWatch {
  private watch: Watch | null = null;

  constructor(
    private readonly timers: Timers,
    private readonly everyMs: number,
    private readonly api: DisputeApi,
    private readonly onOpen: (sessionId: string) => void,
  ) {}

  begin(contactId: string): void {
    this.end();
    const watch: Watch = { contactId, timer: null, opened: false };
    this.watch = watch;
    watch.timer = this.timers.setTimeout(() => this.look(watch), this.everyMs);
  }

  private async look(watch: Watch): Promise<void> {
    if (this.watch !== watch || watch.opened) return;
    try {
      const live = await this.api.live(watch.contactId);
      if (live.formSent && live.dispute && this.watch === watch && !watch.opened) {
        watch.opened = true;
        const { sessionId } = await this.api.open(watch.contactId, live.dispute.disputeId);
        this.onOpen(sessionId);
        return;
      }
    } catch {
      /* disputes aren't set up, or not yet: look again */
    }
    if (this.watch === watch && !watch.opened) watch.timer = this.timers.setTimeout(() => this.look(watch), this.everyMs);
  }

  // The form was opened from the chat's own link: that counts as this conversation's once.
  markOpened(): void {
    if (this.watch) this.watch.opened = true;
  }

  end(): void {
    if (this.watch) this.timers.clearTimeout(this.watch.timer);
    this.watch = null;
  }
}
