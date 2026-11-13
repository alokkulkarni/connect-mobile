import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/di/providers.dart';

// Internet banking with an assistant that knows where you are: a demo on sample data. See README.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A failed load shows its error and a "Try again" button rather than retrying by itself.
  final container = ProviderContainer(retry: (_, _) => null);
  await container.read(sessionControllerProvider).restore(); // signed in or not, before the first screen
  runApp(UncontrolledProviderScope(container: container, child: const BankApp()));
}
