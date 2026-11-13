import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/assistant/presentation/assistant_dock.dart';
import '../../features/assistant/presentation/assistant_launcher.dart';
import '../../features/assistant/presentation/assistant_providers.dart';
import '../../features/cards/presentation/cards_screen.dart';
import '../../features/help/presentation/help_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/money_hub/domain/money_hub.dart';
import '../../features/money_hub/presentation/money_hub_screen.dart';
import '../../features/mortgages/presentation/mortgages_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/session/presentation/session_controller.dart';
import '../../features/session/presentation/sign_in_screen.dart';
import '../../features/settings/presentation/more_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/transactions/domain/transactions.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transactions_list.dart';
import '../di/providers.dart';
import '../webview/form_request.dart';
import '../webview/form_web_view_screen.dart';
import '../widgets/common.dart';

// The app's screens. Five tabs (Home, Accounts, Cards, Money Hub, More), each keeping its own stack, so the customer
// can move around while the assistant stays with them. The router tells ScreenContexts which location is showing.

final rootNavigatorKey = GlobalKey<NavigatorState>();

Page<void> _still(Widget child, GoRouterState state) => NoTransitionPage(key: state.pageKey, child: child);

Widget _detail(GoRouterState state) => TransactionDetailScreen(
  id: state.pathParameters['id'] ?? '',
  initial: state.extra is Transaction ? state.extra as Transaction : null,
);

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.read(sessionControllerProvider);
  final contexts = ref.read(screenContextsProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: session,
    redirect: (context, state) {
      final here = state.matchedLocation;
      if (session.status == SessionStatus.signedOut) return here == '/sign-in' ? null : '/sign-in';
      if (session.status == SessionStatus.signedIn && here == '/sign-in') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/form',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            FormWebViewScreen(request: state.extra is FormRequest ? state.extra as FormRequest : null),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'transactions',
                    builder: (_, _) => const TransactionsScreen(),
                    routes: [GoRoute(path: ':id', builder: (_, state) => _detail(state))],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/accounts/current',
            routes: [
              GoRoute(
                path: '/accounts/:account',
                pageBuilder: (_, state) => _still(AccountsScreen(account: state.pathParameters['account']!), state),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cards', pageBuilder: (_, state) => _still(const CardsScreen(disputesTab: false), state)),
              GoRoute(
                path: '/cards/disputes',
                pageBuilder: (_, state) => _still(const CardsScreen(disputesTab: true), state),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/money-hub/out',
            routes: [
              GoRoute(
                path: '/money-hub/:view',
                pageBuilder: (_, state) => _still(
                  MoneyHubScreen(view: MoneyHubView.fromKey(state.pathParameters['view']) ?? MoneyHubView.out),
                  state,
                ),
                routes: [GoRoute(path: ':id', builder: (_, state) => _detail(state))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(path: 'mortgages', builder: (_, _) => const MortgagesScreen()),
                  GoRoute(path: 'help', builder: (_, _) => const HelpScreen()),
                  GoRoute(path: 'notifications', builder: (_, _) => const NotificationsScreen()),
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // After the router's own notification (never while the tree is building).
  void showing() => scheduleMicrotask(() => contexts.showing(router.routerDelegate.currentConfiguration.uri.path));
  router.routerDelegate.addListener(showing);
  ref.onDispose(() {
    router.routerDelegate.removeListener(showing);
    router.dispose();
  });
  return router;
});

/// The tabs, the assistant launcher above them, and the demo line.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(sessionControllerProvider.select((s) => s.session?.isSample ?? false));
    final dock = ref.watch(assistantDockProvider);
    dock.shellRoute = ModalRoute.of(context); // the assistant docks here while this is the screen on top
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                shell,
                if (!dock.open)
                  const Positioned(left: 16, right: 16, bottom: 12, child: Center(child: AssistantLauncher())),
                // Above the tab bar, leaving the tabs usable during a conversation
                const Positioned.fill(child: AssistantDockPanel()),
              ],
            ),
          ),
          DemoBanner(sample: sample, onSignIn: sample ? () => ref.read(sessionControllerProvider).forget() : null),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Cards',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Money Hub',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
