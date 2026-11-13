// Loads something for a screen, with reload and the customer-facing error message.
import { useCallback, useEffect, useRef, useState } from 'react';

export function useAsync<T>(load: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const alive = useRef(true);

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(load, deps);
  const reload = useCallback(async () => {
    setLoading(true);
    try {
      const value = await run();
      if (alive.current) {
        setData(value);
        setError('');
      }
    } catch (e) {
      if (alive.current) setError(e instanceof Error ? e.message : 'Something went wrong. Try again.');
    } finally {
      if (alive.current) setLoading(false);
    }
  }, [run]);

  useEffect(() => {
    alive.current = true;
    reload();
    return () => {
      alive.current = false;
    };
  }, [reload]);

  return { data, error, loading, reload, setData };
}
