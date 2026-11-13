// The tab bar's measured height (it includes the home-indicator inset), for what floats above it: the assistant's
// launcher and its sheet, which leave the tabs usable during a conversation. 0 until it has been laid out.
import { useSyncExternalStore } from 'react';

let height = 0;
const listeners = new Set<() => void>();

export function setTabBarHeight(next: number): void {
  const rounded = Math.round(next);
  if (rounded === height) return;
  height = rounded;
  listeners.forEach(listener => listener());
}

export function useTabBarHeight(): number {
  return useSyncExternalStore(
    listener => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => height,
  );
}
