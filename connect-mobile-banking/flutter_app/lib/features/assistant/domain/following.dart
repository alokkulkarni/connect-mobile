import 'dart:async';

import 'conversation.dart';
import 'screen_context.dart';

// Following the customer during a conversation, from connect-banking-app/web/app.js. docs/CONTRACT.md section 6.

/// Page moves: a new screen context kept for the settle time is told to the assistant (contact/page), so ARIA's
/// next turn knows where the customer is. Never the context the conversation started on; never the same twice in
/// a row. [app.js pageMoved]
class PageMover {
  PageMover({required this.tell, this.settle = const Duration(milliseconds: 1500)});

  final Future<void> Function(String contactId, ScreenContext context) tell;
  final Duration settle;

  String? _contactId;
  String _toldKey = '';
  Timer? _timer;

  /// A conversation started here: nothing to tell yet.
  void begin(String contactId, ScreenContext start) {
    stop();
    _contactId = contactId;
    _toldKey = start.key;
  }

  /// Something may have moved. [current] is read when the settle time is up, not now.
  void changed(ScreenContext Function() current) {
    final contactId = _contactId;
    if (contactId == null) return;
    _timer?.cancel();
    _timer = Timer(settle, () async {
      final now = current();
      if (_contactId != contactId || now.key == _toldKey) return;
      _toldKey = now.key;
      try {
        await tell(contactId, now);
      } catch (_) {
        // the conversation carries on; the next move tries again
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _contactId = null;
  }
}

/// The dispute watch: during any conversation, when the dispute assistant sends its form (texted on a call, posted
/// in a chat), open it, joined to this conversation. Once per conversation. [app.js watchDisputes]
class DisputeWatch {
  DisputeWatch({required this.backend, required this.onFormSent, this.every = const Duration(seconds: 4)});

  final ConversationBackend backend;
  final void Function(String sessionId) onFormSent;
  final Duration every;

  _Watch? _watch;

  void start(String contactId) {
    stop();
    final watch = _watch = _Watch(contactId);
    watch.timer = Timer(every, () => _look(watch));
  }

  Future<void> _look(_Watch watch) async {
    if (_watch != watch || watch.opened) return;
    try {
      final live = await backend.disputesLive(watch.contactId);
      if (live.formSent && live.disputeId != null && _watch == watch && !watch.opened) {
        watch.opened = true;
        final sessionId = await backend.disputesOpen(watch.contactId, live.disputeId!);
        if (_watch == watch) onFormSent(sessionId);
        return;
      }
    } catch (_) {
      // disputes aren't set up, or not yet: look again
    }
    if (_watch == watch && !watch.opened) watch.timer = Timer(every, () => _look(watch));
  }

  /// The customer opened this conversation's form from the chat's own link: that counts as the once.
  void markOpened() => _watch?.opened = true;

  void stop() {
    _watch?.timer?.cancel();
    _watch = null;
  }
}

class _Watch {
  _Watch(this.contactId);

  final String contactId;
  Timer? timer;
  bool opened = false;
}
