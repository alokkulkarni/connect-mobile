import { ApiError } from './ApiTransport';
import { LinkTransport } from './LinkTransport';
import { SampleTransport } from './SampleTransport';

describe('SampleTransport', () => {
  it('answers with the backend’s own replies, with chat and calls off', async () => {
    const api = new SampleTransport();
    const home = await api.post<any>('app/home');
    expect(home.firstName).toBe('James');
    expect(home.talk).toBe(false);
    expect(home.disputePagesUrl).toBe('');
    await expect(api.post('contact/chat', { page: 'home' })).rejects.toMatchObject({ code: 'talk_unavailable', status: 503 });
  });

  it('filters and pages transactions 25 at a time', async () => {
    const api = new SampleTransport();
    const first = await api.post<any>('transactions', { page: 1 });
    expect(first.transactions).toHaveLength(25);
    expect(first.hasMore).toBe(true);
    const out = await api.post<any>('transactions', { direction: 'in' });
    expect(out.transactions.every((t: any) => t.direction === 'in')).toBe(true);
  });

  it('keeps goals and categories for the session', async () => {
    const api = new SampleTransport();
    await api.post('goal', { name: 'New car', target: 6000, byDate: '2027-10-01', saved: 500 });
    expect((await api.post<any>('hub')).goals.map((g: any) => g.name)).toContain('New car');
    await api.post('goal/delete', { name: 'New car' });
    expect((await api.post<any>('hub')).goals.map((g: any) => g.name)).not.toContain('New car');
    const [t] = (await api.post<any>('transactions', { direction: 'out' })).transactions;
    const moved = await api.post<any>('recategorise', { transactionId: t.transactionId, category: 'gifts' });
    expect(moved.transaction).toMatchObject({ category: 'gifts', recategorised: true });
    await expect(api.post('recategorise', { transactionId: t.transactionId, category: 'salary' })).rejects.toBeInstanceOf(ApiError);
  });
});

describe('LinkTransport', () => {
  it('posts to <origin>/api/<route> with the secret in the body, never in the address', async () => {
    const fetchImpl = jest.fn(async () => ({ ok: true, status: 200, json: async () => ({ fine: true }) }));
    const api = new LinkTransport('https://app-host.example', 'secret-secret-secret', () => {}, fetchImpl as never);
    expect(await api.post('app/home')).toEqual({ fine: true });
    const [url, init] = (fetchImpl.mock.calls[0] as unknown) as [string, { body: string }];
    expect(url).toBe('https://app-host.example/api/app/home');
    expect(JSON.parse(init.body)).toEqual({ token: 'secret-secret-secret' });
  });

  it('tells the app when the link has expired', async () => {
    const onExpired = jest.fn();
    const fetchImpl = jest.fn(async () => ({ ok: false, status: 403, json: async () => ({ error: 'link_expired', message: 'This link has expired. Ask for a new one.' }) }));
    const api = new LinkTransport('https://app-host.example', 'secret-secret-secret', onExpired, fetchImpl as never);
    await expect(api.post('app/home')).rejects.toMatchObject({ code: 'link_expired', message: 'This link has expired. Ask for a new one.' });
    expect(onExpired).toHaveBeenCalled();
  });
});
