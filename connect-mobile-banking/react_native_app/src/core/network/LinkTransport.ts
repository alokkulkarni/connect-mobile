// Link mode: POST <origin>/api/<route> with the session secret in the body, exactly as the web app does
// (banking_api.py web). Logs carry the route and status only, never a body or a token.
import { ApiError, ApiTransport, Json } from './ApiTransport';

type Fetch = typeof fetch;

export class LinkTransport implements ApiTransport {
  readonly mode = 'link' as const;

  constructor(
    private readonly origin: string,
    private readonly secret: string,
    private readonly onExpired: () => void,
    private readonly fetchImpl: Fetch = fetch,
  ) {}

  async post<T = Json>(route: string, body: Json = {}): Promise<T> {
    let response: Response;
    try {
      response = await this.fetchImpl(`${this.origin}/api/${route}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...body, token: this.secret }),
      });
    } catch {
      throw new ApiError('offline', "We couldn't reach internet banking. Check your connection and try again.", 0);
    }
    const reply = (await response.json().catch(() => ({}))) as Json;
    if (!response.ok) {
      if (__DEV__) console.warn(`api ${route} ${response.status}`);
      const error = new ApiError(String(reply.error ?? 'error'), String(reply.message ?? 'Something went wrong. Try again.'), response.status);
      if (error.linkExpired) this.onExpired();
      throw error;
    }
    return reply as T;
  }
}
