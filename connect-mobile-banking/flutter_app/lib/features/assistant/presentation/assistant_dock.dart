import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/theme/tokens.dart';
import 'assistant_sheet.dart';

// The assistant docked in the tab shell: above the tab bar, with the screen behind it still usable, so the customer
// can move between screens during a conversation (and the assistant follows them, docs/CONTRACT.md section 6). Drag
// the handle to resize it: it settles at one of three heights, and dragging it well below the smallest minimises it.
// Screens stacked over the shell (the forms WebView) still get the assistant as a modal sheet. [web/widget/dock.js]

class AssistantDock extends ChangeNotifier {
  bool open = false;

  /// The tab shell's route, set as the shell builds. The dock is usable only while that route is on top.
  ModalRoute<dynamic>? shellRoute;

  bool get available => shellRoute?.isCurrent ?? false;

  void show() {
    if (open) return;
    open = true;
    notifyListeners();
  }

  void hide() {
    if (!open) return;
    open = false;
    notifyListeners();
  }
}

final assistantDockProvider = ChangeNotifierProvider<AssistantDock>((ref) => AssistantDock());

const _snaps = [0.38, 0.62, 1.0]; // of the room above the tab bar
const _start = 1; // opens at the middle height

class AssistantDockPanel extends ConsumerStatefulWidget {
  const AssistantDockPanel({super.key});

  @override
  ConsumerState<AssistantDockPanel> createState() => _AssistantDockPanelState();
}

class _AssistantDockPanelState extends ConsumerState<AssistantDockPanel> {
  double? _height; // null: the starting height
  double _dragFrom = 0;

  @override
  Widget build(BuildContext context) {
    final dock = ref.watch(assistantDockProvider);
    if (!dock.open) {
      _height = null;
      return const SizedBox.shrink();
    }
    final c = context.bank;
    return LayoutBuilder(
      builder: (context, box) {
        final room = (box.maxHeight - 12).clamp(200.0, double.infinity);
        final snaps = [for (final f in _snaps) f * room];
        final height = (_height ?? snaps[_start]).clamp(120.0, room);

        void settle(double wanted) {
          if (wanted < snaps.first * 0.6) {
            ref.read(assistantDockProvider).hide();
            return;
          }
          setState(() => _height = snaps.reduce((best, s) => (s - wanted).abs() < (best - wanted).abs() ? s : best));
        }

        void step(int by) {
          final at = snaps.indexWhere((s) => s >= height - 1);
          setState(() => _height = snaps[(at + by).clamp(0, snaps.length - 1)]);
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            child: Material(
              color: c.card,
              elevation: 16,
              shadowColor: Colors.black45,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  Semantics(
                    label: 'Resize the assistant',
                    hint: 'Swipe up or down to make it taller or shorter. Drag it down to minimise.',
                    onIncrease: () => step(1),
                    onDecrease: () => step(-1),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) => _dragFrom = height,
                      onVerticalDragUpdate: (d) => setState(() => _height = (_height ?? height) - d.delta.dy),
                      // a flick carries on a little
                      onVerticalDragEnd: (d) => settle((_height ?? height) - (d.primaryVelocity ?? 0) * 0.12),
                      onVerticalDragCancel: () => setState(() => _height = _dragFrom),
                      child: SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: AssistantSheet(docked: true, onDismiss: ref.read(assistantDockProvider).hide)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
