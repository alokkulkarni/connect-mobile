import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/screen_context.dart';
import 'assistant_providers.dart';
import 'screen_contexts.dart';

/// Wrap a screen to tell the assistant what it is, for the location it's shown at.
class ScreenContextScope extends ConsumerWidget {
  const ScreenContextScope({super.key, required this.screen, required this.child});

  final ScreenContext screen;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PublishContext(
        contexts: ref.read(screenContextsProvider),
        path: GoRouterState.of(context).uri.path,
        context: screen,
        child: child,
      );
}
