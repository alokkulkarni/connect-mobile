// A screen tells the assistant where the customer is, whenever it is in front and whenever that changes
// (a Money Hub tab, a chosen payment). Pass null until the screen knows (its data hasn't loaded yet).
import { useCallback, useRef } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { useApp } from '../../../app/AppContext';
import type { ScreenContext } from '../domain/screenContext';

export function useScreenContext(context: ScreenContext | null): void {
  const { container } = useApp();
  const key = context ? JSON.stringify(context) : '';
  const latest = useRef(context);
  latest.current = context;
  useFocusEffect(
    useCallback(() => {
      if (latest.current) container.assistant.setContext(latest.current);
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [container, key]),
  );
}
