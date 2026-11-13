// Who is signed in, and how. The demo has no username or password: the internet banking link stands for the
// customer signed in (CONTRACT.md section 1). Sample mode needs no link and never reaches a backend.

export type Session = { mode: 'sample' } | { mode: 'link'; origin: string; secret: string };

export interface SessionRepository {
  load(): Promise<Session | null>;
  save(session: Session): Promise<void>;
  clear(): Promise<void>;
}

const SECRET = /^[A-Za-z0-9_-]{16,128}$/;
const ORIGIN = /^https:\/\/([A-Za-z0-9-]+\.)+[A-Za-z0-9-]+(:\d{1,5})?$/;

export type ParsedLink = { ok: true; origin: string; secret: string } | { ok: false; reason: string };

// https://<app-host>/<any path>#k=<secret>  ->  the API base (origin) and the session secret.
export function parseLink(text: string): ParsedLink {
  const link = String(text || '').trim();
  const hashAt = link.indexOf('#');
  if (hashAt < 0) return { ok: false, reason: "That isn't an internet banking link. It should end with #k= and a code." };
  const before = link.slice(0, hashAt);
  const match = before.match(/^(https?:\/\/[^/?#]+)/i);
  if (!match) return { ok: false, reason: "That isn't an internet banking link." };
  const origin = match[1];
  if (!/^https:/i.test(origin)) return { ok: false, reason: 'Only secure (https) links can be used.' };
  if (!ORIGIN.test(origin)) return { ok: false, reason: "That isn't an internet banking link." };
  const params = link
    .slice(hashAt + 1)
    .split('&')
    .map((pair) => pair.split('='));
  const found = params.find(([key]) => key === 'k');
  const secret = found ? decodeURIComponent(found[1] || '') : '';
  if (!SECRET.test(secret)) return { ok: false, reason: "That link's code isn't right. Copy the whole link and try again." };
  return { ok: true, origin: origin.toLowerCase(), secret };
}

// The use cases the sign-in screen and Settings call.
export class SessionUseCases {
  constructor(private readonly repository: SessionRepository) {}

  restore = () => this.repository.load();

  async signInWithLink(text: string): Promise<Session> {
    const parsed = parseLink(text);
    if (!parsed.ok) throw new Error(parsed.reason);
    const session: Session = { mode: 'link', origin: parsed.origin, secret: parsed.secret };
    await this.repository.save(session);
    return session;
  }

  // Sample mode lives in memory only, and forgets any saved link: the next launch opens on sign-in, so the customer
  // can always get back to pasting their link.
  async startSample(): Promise<Session> {
    await this.repository.clear().catch(() => {});
    return { mode: 'sample' };
  }

  signOut = () => this.repository.clear();
}
