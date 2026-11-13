import { parseLink, SessionUseCases, Session, SessionRepository } from './session';

const SECRET = 'AbCdEfGhIjKlMnOpQrStUv_-12';

describe('parseLink', () => {
  it('takes the origin and the secret from a link', () => {
    expect(parseLink(`https://app-host.example/#k=${SECRET}`)).toEqual({ ok: true, origin: 'https://app-host.example', secret: SECRET });
  });

  it('accepts any path and other hash parameters', () => {
    expect(parseLink(`  https://App-Host.example/money-hub#x=1&k=${SECRET}  `)).toEqual({ ok: true, origin: 'https://app-host.example', secret: SECRET });
  });

  it('refuses http', () => {
    expect(parseLink(`http://app-host.example/#k=${SECRET}`).ok).toBe(false);
  });

  it('refuses a link with no secret, or a malformed one', () => {
    expect(parseLink('https://app-host.example/').ok).toBe(false);
    expect(parseLink('https://app-host.example/#k=short').ok).toBe(false);
    expect(parseLink('https://app-host.example/#k=has spaces in it here').ok).toBe(false);
    expect(parseLink(`https://app-host.example/#k=${'a'.repeat(129)}`).ok).toBe(false);
  });

  it('refuses something that is not a web address', () => {
    expect(parseLink(`javascript:alert(1)#k=${SECRET}`).ok).toBe(false);
    expect(parseLink(`https://localhost/#k=${SECRET}`).ok).toBe(false);
  });
});

describe('SessionUseCases', () => {
  it('keeps a link session and clears it on sign-out', async () => {
    let stored: Session | null = null;
    const repository: SessionRepository = {
      load: async () => stored,
      save: async (s) => {
        stored = s;
      },
      clear: async () => {
        stored = null;
      },
    };
    const sessions = new SessionUseCases(repository);
    await sessions.signInWithLink(`https://app-host.example/#k=${SECRET}`);
    expect(await sessions.restore()).toEqual({ mode: 'link', origin: 'https://app-host.example', secret: SECRET });
    await sessions.signOut();
    expect(await sessions.restore()).toBeNull();
    await expect(sessions.signInWithLink('nope')).rejects.toThrow();
  });

  it('never saves Sample mode, and forgets a saved link, so the next launch opens on sign-in', async () => {
    let stored: Session | null = null;
    const saves: Session[] = [];
    const repository: SessionRepository = {
      load: async () => stored,
      save: async (s) => {
        saves.push(s);
        stored = s;
      },
      clear: async () => {
        stored = null;
      },
    };
    const sessions = new SessionUseCases(repository);
    await sessions.signInWithLink(`https://app-host.example/#k=${SECRET}`);
    expect(await sessions.startSample()).toEqual({ mode: 'sample' });
    expect(saves.map((s) => s.mode)).toEqual(['link']);
    expect(await sessions.restore()).toBeNull();
  });

  it('still starts Sample mode when the secure store fails', async () => {
    const repository: SessionRepository = {
      load: async () => null,
      save: async () => {},
      clear: async () => {
        throw new Error('keychain unavailable');
      },
    };
    expect(await new SessionUseCases(repository).startSample()).toEqual({ mode: 'sample' });
  });
});
