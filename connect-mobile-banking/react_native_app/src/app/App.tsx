// The app: restore the session (or sign in), then the signed-in app with the assistant over every screen.
import React, {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { AppState, Linking, StatusBar, View } from 'react-native';
import {
  DarkTheme,
  DefaultTheme,
  NavigationContainer,
} from '@react-navigation/native';
import {
  SafeAreaInsetsContext,
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import { EXPIRED_WORDS } from '../core/network/ApiTransport';
import { ThemeProvider, useTheme } from '../core/theme/theme';
import { DemoBanner, Loading, Problem, Screen } from '../core/ui/kit';
import { AssistantLauncher } from '../features/assistant/presentation/AssistantLauncher';
import { AssistantSheet } from '../features/assistant/presentation/AssistantSheet';
import type { HomeSummary } from '../features/home/domain/home';
import {
  intentInbox,
  runIntent,
} from '../features/notifications/presentation/intents';
import { KeychainSessionRepository } from '../features/session/data/KeychainSessionRepository';
import {
  Session,
  SessionRepository,
  SessionUseCases,
} from '../features/session/domain/session';
import { SignInScreen } from '../features/session/presentation/SignInScreen';
import { AppContext, AppValue } from './AppContext';
import { Container, createContainer } from './di';
import { RootNavigator } from './navigation/RootNavigator';
import { navigationRef, TAB_ROUTES } from './navigation/routes';
import { useTabBarHeight } from './navigation/tabBarHeight';
import { startPush } from './push';

export default function App({
  repository,
}: {
  repository?: SessionRepository;
}) {
  return (
    <SafeAreaProvider>
      <ThemeProvider>
        <Root repository={repository} />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

function Root({ repository }: { repository?: SessionRepository }) {
  const sessions = useMemo(
    () => new SessionUseCases(repository || new KeychainSessionRepository()),
    [repository],
  );
  const [session, setSession] = useState<Session | null | undefined>(undefined);
  const [notice, setNotice] = useState('');
  const [generation, setGeneration] = useState(0);

  const signInWithLink = useCallback(
    async (link: string) => {
      const next = await sessions.signInWithLink(link);
      setNotice('');
      setGeneration(g => g + 1);
      setSession(next);
    },
    [sessions],
  );

  useEffect(() => {
    startPush().catch(() => {});
    sessions.restore().then(s => setSession(s));
  }, [sessions]);

  // Opened from the link itself (a verified Universal Link or App Link; never a custom scheme).
  useEffect(() => {
    const fromUrl = (url: string | null | undefined) => {
      if (url && url.includes('#k='))
        signInWithLink(url).catch(() =>
          setNotice(
            "That link didn't work. Open your internet banking from a new link.",
          ),
        );
    };
    Linking.getInitialURL()
      .then(fromUrl)
      .catch(() => {});
    const subscription = Linking.addEventListener('url', event =>
      fromUrl(event.url),
    );
    return () => subscription.remove();
  }, [signInWithLink]);

  const signOut = useCallback(
    async (words = '') => {
      await sessions.signOut().catch(() => {});
      setNotice(words);
      setSession(null);
    },
    [sessions],
  );

  if (session === undefined) return <Loading words="Opening…" />;
  if (!session) {
    return (
      <SignInScreen
        notice={notice}
        onLink={signInWithLink}
        onSample={async () => {
          const next = await sessions.startSample();
          setNotice('');
          setGeneration(g => g + 1);
          setSession(next);
        }}
      />
    );
  }
  return <SignedIn key={generation} session={session} signOut={signOut} />;
}

function SignedIn({
  session,
  signOut,
}: {
  session: Session;
  signOut: (words?: string) => Promise<void>;
}) {
  const theme = useTheme();
  const expired = useRef(false);
  const container: Container = useMemo(
    () =>
      createContainer(session, () => {
        if (expired.current) return;
        expired.current = true;
        signOut(EXPIRED_WORDS);
      }),
    [session, signOut],
  );
  const [me, setMe] = useState<HomeSummary | null>(null);
  const [problem, setProblem] = useState('');
  const [route, setRoute] = useState('');
  const [ready, setReady] = useState(false);
  const insets = useSafeAreaInsets();
  const tabBarHeight = useTabBarHeight();
  const belowBanner = useMemo(() => ({ ...insets, top: 0 }), [insets]); // the demo banner already sits under the status bar

  const reloadMe = useCallback(async () => {
    try {
      const next = await container.home.home();
      setMe(next);
      setProblem('');
      container.assistant.configure(next.talk, next.disputePagesUrl);
    } catch (e) {
      setProblem(
        e instanceof Error ? e.message : 'Something went wrong. Try again.',
      );
    }
  }, [container]);

  useEffect(() => {
    reloadMe();
  }, [reloadMe]);

  // The assistant outlives screens, not the session: signing out ends any conversation.
  useEffect(
    () => () => {
      container.assistant.end();
    },
    [container],
  );

  // C13: the background never ends a chat; coming back rejoins it if its socket closed.
  useEffect(() => {
    const subscription = AppState.addEventListener('change', state =>
      container.assistant.setForeground(state === 'active'),
    );
    return () => subscription.remove();
  }, [container]);

  // Forms the assistant asks to open: the chat's own dispute link, or the dispute form the watch found.
  useEffect(
    () =>
      container.assistant.onForm(request => {
        if (!navigationRef.isReady()) return;
        navigationRef.navigate(
          'Form',
          request.kind === 'link'
            ? { kind: 'link', url: request.url }
            : { kind: 'disputeSession', sessionId: request.sessionId },
        );
      }),
    [container],
  );

  // Notification intents, once signed in and the screens are ready (CONTRACT.md section 7, step 2).
  useEffect(() => {
    if (!ready || !me) return;
    const drain = () => {
      let intent = intentInbox.take();
      while (intent) {
        runIntent(intent, navigationRef, container.assistant);
        intent = intentInbox.take();
      }
    };
    drain();
    return intentInbox.subscribe(drain);
  }, [ready, me, container]);

  const value: AppValue | null = useMemo(
    () => (me ? { container, me, reloadMe, signOut } : null),
    [container, me, reloadMe, signOut],
  );

  if (!value) {
    return problem ? (
      <Screen>
        <Problem words={problem} onRetry={reloadMe} />
      </Screen>
    ) : (
      <Loading words="Opening your internet banking…" />
    );
  }

  const navTheme = theme.dark
    ? {
        ...DarkTheme,
        colors: {
          ...DarkTheme.colors,
          background: theme.c.bg,
          card: theme.c.card,
          primary: theme.c.brand2,
          text: theme.c.ink,
          border: theme.c.line,
        },
      }
    : {
        ...DefaultTheme,
        colors: {
          ...DefaultTheme.colors,
          background: theme.c.bg,
          card: theme.c.card,
          primary: theme.c.brand2,
          text: theme.c.ink,
          border: theme.c.line,
        },
      };

  return (
    <AppContext.Provider value={value}>
      <StatusBar barStyle="light-content" />
      <View style={{ flex: 1, backgroundColor: theme.c.bg }}>
        <DemoBanner
          onSignIn={session.mode === 'sample' ? () => signOut('') : undefined}
        />
        <SafeAreaInsetsContext.Provider value={belowBanner}>
          <NavigationContainer
            ref={navigationRef}
            theme={navTheme}
            onReady={() => {
              setReady(true);
              setRoute(navigationRef.getCurrentRoute()?.name || '');
            }}
            onStateChange={() =>
              setRoute(navigationRef.getCurrentRoute()?.name || '')
            }
          >
            <RootNavigator />
          </NavigationContainer>
        </SafeAreaInsetsContext.Provider>
        {/* Above the tab bar on the tab screens, so the customer can change screen during a conversation */}
        <AssistantLauncher
          route={route}
          bottomInset={
            TAB_ROUTES.has(route)
              ? tabBarHeight || 62 + insets.bottom
              : insets.bottom
          }
        />
        <AssistantSheet
          bottomInset={
            TAB_ROUTES.has(route) ? tabBarHeight || 62 + insets.bottom : 0
          }
        />
      </View>
    </AppContext.Provider>
  );
}
