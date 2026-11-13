// Timers and identifiers behind small interfaces, so the assistant's engines can be tested with fake time.

export type TimerHandle = unknown;

export interface Timers {
  setTimeout(fn: () => void, ms: number): TimerHandle;
  clearTimeout(handle: TimerHandle): void;
  setInterval(fn: () => void, ms: number): TimerHandle;
  clearInterval(handle: TimerHandle): void;
}

export const realTimers: Timers = {
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (h) => clearTimeout(h as ReturnType<typeof setTimeout>),
  setInterval: (fn, ms) => setInterval(fn, ms),
  clearInterval: (h) => clearInterval(h as ReturnType<typeof setInterval>),
};

// A version 4 UUID for Connect's ClientToken. crypto.getRandomValues comes from react-native-get-random-values
// (loaded first in index.js).
export function uuid(): string {
  const bytes = new Uint8Array(16);
  const c = (globalThis as { crypto?: { getRandomValues?: (a: Uint8Array) => Uint8Array } }).crypto;
  if (c?.getRandomValues) c.getRandomValues(bytes);
  else for (let i = 0; i < 16; i++) bytes[i] = Math.floor(Math.random() * 256);
  // eslint-disable-next-line no-bitwise
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  // eslint-disable-next-line no-bitwise
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

// Something that can be listened to: the presentation layer reads it with useSyncExternalStore.
export class Observable<T> {
  private listeners = new Set<() => void>();
  constructor(protected state: T) {}
  getSnapshot = (): T => this.state;
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };
  protected set(next: Partial<T>): void {
    this.state = { ...this.state, ...next };
    this.listeners.forEach((l) => l());
  }
}
