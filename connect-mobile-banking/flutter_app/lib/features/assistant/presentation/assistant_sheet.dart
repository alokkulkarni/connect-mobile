import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../session/domain/session.dart';
import '../../../core/di/providers.dart';
import '../domain/chat_rules.dart';
import '../domain/conversation.dart';
import 'assistant_dock.dart';
import 'assistant_providers.dart';

// The assistant: start a chat or call, the conversation, and its controls. On the tab screens it's docked above the
// tab bar (assistant_dock.dart), so the customer can change screen while it follows them; over other screens it's a
// modal sheet. Minimising (dragging it down, or the – button) keeps the conversation going behind the launcher; ×
// ends it.
// [web/widget/dock.js, talk.js]

// The sheet showing now, if any: a second request starts its conversation there rather than opening another.
_AssistantSheetState? _open;

/// Opens the assistant. [startWith] starts that kind of conversation at once (a notification about money).
Future<void> showAssistantSheet(BuildContext context, {ConversationKind? startWith}) async {
  final open = _open;
  if (open != null && open.mounted) {
    if (startWith != null) open.ref.read(assistantControllerProvider).start(startWith);
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final dock = container.read(assistantDockProvider);
  if (dock.available) {
    dock.show();
    final assistant = container.read(assistantControllerProvider);
    if (startWith != null && !assistant.live) assistant.start(startWith);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: context.bank.card,
    builder: (_) => AssistantSheet(startWith: startWith),
  );
}

class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({super.key, this.startWith, this.docked = false, this.onDismiss});

  final ConversationKind? startWith;

  /// Docked above the tab bar: its panel sets the height, and the shell keeps it above the keyboard.
  final bool docked;

  /// Minimising or closing; the modal sheet pops itself when this is null.
  final VoidCallback? onDismiss;

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _shownLines = 0;

  @override
  void initState() {
    super.initState();
    _open = this;
    final assistant = ref.read(assistantControllerProvider);
    if (!assistant.live || assistant.kind == ConversationKind.chat) _input.text = assistant.context.draft;
    final start = widget.startWith;
    if (start != null && !assistant.live) WidgetsBinding.instance.addPostFrameCallback((_) => assistant.start(start));
  }

  @override
  void dispose() {
    if (_open == this) _open = null;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _followLog(int count) {
    if (count == _shownLines) return;
    _shownLines = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _dismiss() {
    final dismiss = widget.onDismiss;
    if (dismiss != null) {
      dismiss();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _send() async {
    final words = _input.text.trim();
    if (words.isEmpty) return;
    _input.clear();
    await ref.read(assistantControllerProvider).send(words);
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantControllerProvider);
    ref.watch(screenContextsProvider); // the screen it follows
    final sample = ref.watch(sessionControllerProvider.select((c) => c.session?.mode == SessionMode.sample));
    final c = context.bank;
    final screen = assistant.context;
    _followLog(assistant.lines.length);
    final body = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nationwide assistant',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          assistant.live ? 'Following you: ${screen.label}' : 'You\'re on ${screen.label}',
                          style: TextStyle(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Minimise the assistant',
                    icon: const Icon(Icons.expand_more),
                    onPressed: _dismiss,
                  ),
                  IconButton(
                    tooltip: assistant.live ? 'End and close the assistant' : 'Close the assistant',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (assistant.live) assistant.hangUp();
                      _dismiss();
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            if (assistant.status.isNotEmpty)
              Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  color: c.background,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      if (assistant.live) _LiveDot(color: c.moneyIn),
                      if (assistant.live) const SizedBox(width: 8),
                      Expanded(
                        child: Text(assistant.status, style: TextStyle(color: c.muted, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: assistant.live
                  ? ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: assistant.lines.length,
                      itemBuilder: (_, i) => _Bubble(line: assistant.lines[i], onOpenForm: assistant.openDisputeLink),
                    )
                  : _StartPanel(
                      label: screen.label,
                      canTalk: assistant.canTalk,
                      sample: sample,
                      onChat: () => assistant.start(ConversationKind.chat),
                      onCall: () => assistant.start(ConversationKind.call),
                    ),
            ),
            if (assistant.kind == ConversationKind.chat) _chatFoot(assistant.inputEnabled, assistant.hangUp),
            if (assistant.kind == ConversationKind.call)
              _callFoot(assistant.muted, assistant.toggleMute, assistant.hangUp),
          ],
        );
    if (widget.docked) return body;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.78, child: body),
    );
  }

  Widget _chatFoot(bool enabled, Future<void> Function() end) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(hintText: enabled ? 'Type your message' : 'Connecting…', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Send', onPressed: enabled ? _send : null, icon: const Icon(Icons.send)),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: end, child: const Text('End chat')),
          ),
        ],
      ),
    ),
  );

  Widget _callFoot(bool muted, Future<void> Function() mute, Future<void> Function() end) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: mute,
              icon: Icon(muted ? Icons.mic_off : Icons.mic),
              label: Text(muted ? 'Unmute' : 'Mute'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: context.bank.moneyOut),
              onPressed: end,
              icon: const Icon(Icons.call_end),
              label: const Text('End call'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.label,
    required this.canTalk,
    required this.sample,
    required this.onChat,
    required this.onCall,
  });

  final String label;
  final bool canTalk, sample;
  final VoidCallback onChat, onCall;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.brand.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(BankColors.radius),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Chat or talk with our assistant. It can see which screen you\'re on, starting with ',
                ),
                TextSpan(
                  text: label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: canTalk ? onChat : null,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canTalk ? onCall : null,
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!canTalk)
          Text(
            sample
                ? 'Chat and calls need your internet banking link. You\'re exploring sample data on this phone.'
                : 'Calls and chats aren\'t set up for this app yet.',
            style: TextStyle(color: c.moneyOut),
          ),
        const SizedBox(height: 8),
        Text(
          'It\'s an AI assistant, not a person. Ask at any time to speak to one of our colleagues.',
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.line, required this.onOpenForm});

  final ChatLine line;
  final void Function(String link) onOpenForm;

  @override
  Widget build(BuildContext context) {
    final c = context.bank;
    final me = line.speaker == Speaker.customer;
    final colour = me ? (Theme.of(context).brightness == Brightness.light ? c.brand : c.brand2) : c.background;
    final ink = me ? Colors.white : c.ink;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(me ? 16 : 4),
              bottomRight: Radius.circular(me ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                me ? 'You' : 'Assistant',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    for (final part in amountParts(line.text))
                      TextSpan(
                        text: part.text,
                        style: part.amount ? const TextStyle(fontWeight: FontWeight.w800) : null,
                      ),
                  ],
                ),
                style: TextStyle(color: ink, height: 1.35),
              ),
              if (line.disputeLink != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => onOpenForm(line.disputeLink!),
                  child: const Text('Open the form here'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

/// The live dot, for the launcher.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => _LiveDot(color: color);
}
