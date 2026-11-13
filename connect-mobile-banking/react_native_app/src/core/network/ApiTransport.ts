// One way to reach the bank's API: post(route, body) → JSON. Sample mode answers from bundled fixtures; Link mode
// calls the deployed banking app's own /api/* routes with the session secret; a later sign-in (the /mobile/v1 front
// door, CONTRACT.md section 1) is one more transport. No screen knows which one it has.

export type Json = Record<string, unknown>;

export interface ApiTransport {
  readonly mode: 'sample' | 'link';
  post<T = Json>(route: string, body?: Json): Promise<T>;
}

// An error the API answered with ({error, message}). `message` is written for customers.
export class ApiError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get linkExpired(): boolean {
    return this.status === 403 && this.code === 'link_expired';
  }
}

export const EXPIRED_WORDS = 'That link no longer works. Open your internet banking from a new link.';
