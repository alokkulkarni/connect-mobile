import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:connect_banking/app.dart';
import 'package:connect_banking/core/di/providers.dart';
import 'package:connect_banking/features/notifications/domain/assist_intent.dart';
import 'package:connect_banking/features/notifications/presentation/notifications_providers.dart';
import 'package:connect_banking/features/session/domain/session.dart';
import 'package:connect_banking/features/session/presentation/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The app in Sample mode: it boots, every tab shows, and a notification tap goes through the one handler to the
// right screen and opens the assistant there.
class _MemorySessions implements SessionRepository {
  _MemorySessions(this.saved);

  Session? saved;

  @override
  Future<Session?> load() async => saved;

  @override
  Future<void> save(Session session) async => saved = session;

  @override
  Future<void> forget() async => saved = null;
}

class _FakePush implements PushSource {
  final _taps = StreamController<Map<String, Object?>>.broadcast();

  void tap(Map<String, Object?> data) => _taps.add(data);

  @override
  Future<void> start() async {}

  @override
  Future<Map<String, Object?>?> launchData() async => null;

  @override
  Stream<Map<String, Object?>> get taps => _taps.stream;

  @override
  Stream<({String title, String body, Map<String, Object?> data})> get foreground => const Stream.empty();
}

Future<(ProviderContainer, _FakePush)> _boot(WidgetTester tester, {Session? session = const Session.sample()}) async {
  // A phone-sized screen.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final sessions = SessionController(_MemorySessions(session));
  await sessions.restore();
  final push = _FakePush();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sessionControllerProvider.overrideWith((ref) => sessions),
      fixtureLoaderProvider.overrideWithValue((name) async => File('assets/fixtures/$name.json').readAsStringSync()),
      pushSourcesProvider.overrideWithValue([push]),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const BankApp()));
  await tester.pumpAndSettle();
  return (container, push);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 70; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out, it asks for the link or sample data', (tester) async {
    await _boot(tester, session: null);
    expect(find.text('Open my banking'), findsOneWidget);
    await tester.ensureVisible(find.text('Explore with sample data'));
    await tester.tap(find.text('Explore with sample data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('James'), findsWidgets);
  });

  testWidgets('boots in Sample mode and visits every tab', (tester) async {
    await _boot(tester);
    expect(find.textContaining('James'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Latest payments'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Latest payments'), findsOneWidget);
    expect(find.text('Ask us anything'), findsWidgets); // the launcher, with Home's words

    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget); // the account switch
    expect(find.text('£2,828.80'), findsOneWidget);

    await tester.tap(find.text('Cards').last);
    await tester.pumpAndSettle();
    expect(find.text('Help with a payment'), findsOneWidget);
    expect(find.text('Dispute'), findsWidgets);

    await tester.tap(find.text('Money Hub').last);
    await tester.pumpAndSettle();
    expect(find.text('Money out each month'), findsOneWidget);
    expect(find.text('Ask about your money'), findsOneWidget);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);

    // The launcher opens the assistant, which explains Sample mode has no chat.
    await tester.tap(find.text('Ask us anything').first);
    await tester.pumpAndSettle();
    expect(find.text('Nationwide assistant'), findsOneWidget);
    expect(find.textContaining('Chat and calls need your internet banking link'), findsOneWidget);
  });

  testWidgets('the open assistant leaves the tab bar usable, and follows the customer to the new screen', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('Ask us anything').first);
    await tester.pumpAndSettle();
    expect(find.text("You're on Home"), findsOneWidget);

    await tester.tap(find.text('Money Hub').last); // the tab bar, under the docked assistant
    await tester.pumpAndSettle();
    expect(find.text('Nationwide assistant'), findsOneWidget); // still open
    expect(find.textContaining("You're on Money Hub"), findsOneWidget);

    // Dragging the handle well down minimises it; the launcher comes back.
    await tester.drag(find.bySemanticsLabel('Resize the assistant'), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.text('Nationwide assistant'), findsNothing);
    expect(find.text('Ask about your money'), findsOneWidget);
  });

  testWidgets('a notification tap goes to its screen and opens the assistant there', (tester) async {
    final (_, push) = await _boot(tester);
    push.tap({'v': '1', 'intent': 'assist', 'topic': 'salary_in', 'mode': 'chat'});
    await _settle(tester);
    expect(find.text('Nationwide assistant'), findsOneWidget);
    expect(find.text("You're on Money Hub · Money in"), findsOneWidget);
  });

  testWidgets('an unusual payment notification chooses that payment on Cards', (tester) async {
    final (_, push) = await _boot(tester);
    push.tap({'v': '1', 'intent': 'assist', 'topic': 'unusual_payment', 'mode': 'chat', 'paymentId': 'TXN-2291-20261006-34900'});
    await _settle(tester);
    expect(find.text("You're on Disputing Electroworld Online £349.00"), findsOneWidget);
  });
}
