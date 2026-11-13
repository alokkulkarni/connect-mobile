// What every screen can reach: the session's container, the customer (app/home), and signing out.
import { createContext, useContext, useEffect, useSyncExternalStore } from 'react';
import type { Container } from './di';
import type { HomeSummary } from '../features/home/domain/home';
import type { AssistantState } from '../features/assistant/domain/assistantController';

export type AppValue = {
  container: Container;
  me: HomeSummary;
  reloadMe: () => Promise<void>;
  signOut: (words?: string) => Promise<void>;
};

export const AppContext = createContext<AppValue | null>(null);

export function useApp(): AppValue {
  const value = useContext(AppContext);
  if (!value) throw new Error('useApp outside the signed-in app');
  return value;
}

export function useAssistant(): [AssistantState, Container['assistant']] {
  const { container } = useApp();
  const assistant = container.assistant;
  const state = useSyncExternalStore(assistant.subscribe, assistant.getSnapshot);
  return [state, assistant];
}

// Reload when the assistant may have changed something (a goal saved, a payment moved; CONTRACT.md C15).
// A burst of messages reloads once.
export function useRefreshOnActivity(reload: () => void): void {
  const { container } = useApp();
  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined;
    const stop = container.assistant.onActivity(() => {
      clearTimeout(timer);
      timer = setTimeout(reload, 800);
    });
    return () => {
      clearTimeout(timer);
      stop();
    };
  }, [container, reload]);
}
