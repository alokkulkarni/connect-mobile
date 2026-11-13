import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../domain/conversation.dart';
import 'assistant_providers.dart';
import 'assistant_sheet.dart';

// "Ask us anything" above the tab bar on every screen, its words changing with the screen, with a live dot while
// a conversation is going. [web/widget/dock.js]
class AssistantLauncher extends ConsumerWidget {
  const AssistantLauncher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistant = ref.watch(assistantControllerProvider);
    ref.watch(screenContextsProvider); // the words follow the screen
    final c = context.bank;
    final screen = assistant.context;
    final title = switch (assistant.kind) {
      ConversationKind.chat => 'Chat in progress',
      ConversationKind.call => 'Call in progress',
      null => screen.launcher,
    };
    return Semantics(
      button: true,
      label: '$title. ${screen.label}. Opens the assistant.',
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).brightness == Brightness.light ? c.brand : c.brand2,
        elevation: 6,
        shadowColor: Colors.black38,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showAssistantSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (assistant.live)
                LiveDot(color: c.moneyIn)
              else
                const Icon(Icons.support_agent, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(screen.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
