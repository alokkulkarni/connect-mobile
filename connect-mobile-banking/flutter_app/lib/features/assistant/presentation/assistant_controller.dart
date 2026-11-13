import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/call_session.dart';
import '../domain/chat_session.dart';
import '../domain/conversation.dart';
import '../domain/following.dart';
import '../domain/form_bridge.dart';
import '../domain/screen_context.dart';
import 'screen_contexts.dart';

// The assistant for the whole app: one chat or call at a time, outliving screens as the web widget outlives pages.
// Screens publish their context (ScreenContexts); this never reaches into them. It follows the customer between
// screens (PageMover) and watches for the dispute form (DisputeWatch). docs/CONTRACT.md sections 4 to 6.
class AssistantController extends ChangeNotifier implements ConversationListener {
  AssistantController({
    required this.backend,
    required this.participant,
    required this.connect,
    required this.media,
    required this.microphone,
    required this.contexts,
    required this.newId,
    required this.talkAvailable,
    required this.disputePagesUrl,
    required this.onDataChanged,
    this.chatTimings = const ChatTimings(),
    this.callTimings = const CallTimings(),
    Duration pageSettle = const Duration(milliseconds: 1500),
    Duration disputeWatch = const Duration(seconds: 4),
  }) {
    _mover = PageMover(tell: backend.pageMoved, settle: pageSettle);
    _watch = DisputeWatch(backend: backend, onFormSent: _formSent, every: disputeWatch);
    contexts.addListener(_screenChanged);
  }

  final ConversationBackend backend;
  final ParticipantApi participant;
  final SocketConnector connect;
  final CallMedia media;
  final Microphone microphone;
  final ScreenContexts contexts;
  final String Function() newId;
  final bool Function() talkAvailable;
  final String Function() disputePagesUrl;
  final VoidCallback onDataChanged;
  final ChatTimings chatTimings;
  final CallTimings callTimings;

  /// Opens a shared form (set by the app once its router exists).
  void Function(FormOpening opening)? openForm;

  late final PageMover _mover;
  late final DisputeWatch _watch;
  ChatSession? _chat;
  CallSession? _call;
  ScreenContext _startedFrom = ScreenContext.home;
  bool _tellForm = false; // the mortgage form asked for this call: tell it once the call starts

  /// The page → app events for the forms WebView.
  final _formScripts = StreamController<String>.broadcast();
  Stream<String> get formScripts => _formScripts.stream;

  ConversationKind? kind; // the conversation going on now, if any
  String status = '';
  final List<ChatLine> lines = [];
  bool inputEnabled = false;
  bool muted = false;
  String journey = '';

  bool get live => kind != null;
  bool get canTalk => talkAvailable();
  ScreenContext get context => contexts.current;

  /// Start a chat or a call from the screen showing (or from [from], for the form's own call).
  Future<void> start(ConversationKind next, {ScreenContext? from, bool fromForm = false}) async {
    if (live || !canTalk) return;
    _startedFrom = from ?? contexts.current;
    _tellForm = fromForm;
    lines.clear();
    kind = next;
    inputEnabled = false;
    muted = false;
    journey = '';
    notifyListeners();
    if (next == ConversationKind.chat) {
      final chat = _chat = ChatSession(
        backend: backend,
        participant: participant,
        connect: connect,
        listener: this,
        newId: newId,
        disputePagesUrl: disputePagesUrl(),
        timings: chatTimings,
      );
      await chat.start(_startedFrom);
    } else {
      final call = _call = CallSession(
        backend: backend,
        participant: participant,
        media: media,
        microphone: microphone,
        listener: this,
        newId: newId,
        timings: callTimings,
      );
      await call.start(_startedFrom);
    }
  }

  Future<void> send(String words) async => _chat?.send(words);

  Future<void> toggleMute() async => _call?.toggleMute();

  /// End the conversation, telling Connect.
  Future<void> hangUp() async {
    if (_chat != null) {
      await _chat!.hangUp();
    } else if (_call != null) {
      await _call!.hangUp();
    }
  }

  /// C13: a chat survives the background and reconnects on return.
  void setForeground(bool foreground) => _chat?.setForeground(foreground);

  /// C9: "Open the form here" on the dispute assistant's link. Counts as the dispute watch's once.
  void openDisputeLink(String link) {
    _watch.markOpened();
    openForm?.call(FormOpening.disputeLink(link));
  }

  void _formSent(String sessionId) {
    status = 'Your dispute is open on the Cards screen, under Your disputes. Watch it fill in as you talk.';
    notifyListeners();
    openForm?.call(FormOpening.disputeSession(sessionId));
  }

  void _screenChanged() => _mover.changed(() => contexts.current);

  // ConversationListener

  @override
  void onStatus(String words) {
    status = words;
    notifyListeners();
  }

  @override
  void onStarted(String contactId, String journey, ConversationKind kind) {
    this.journey = journey;
    _mover.begin(contactId, _startedFrom); // where it started: nothing to tell yet
    _watch.start(contactId);
    if (_tellForm) {
      final script = mortgageCallStartedScript(contactId);
      if (script.isNotEmpty) _formScripts.add(script);
    }
    notifyListeners();
  }

  @override
  void onLine(ChatLine line) {
    lines.add(line);
    notifyListeners();
  }

  @override
  void onInputEnabled(bool enabled) {
    inputEnabled = enabled;
    notifyListeners();
  }

  @override
  void onMuted(bool muted) {
    this.muted = muted;
    notifyListeners();
  }

  @override
  void onAssistantActivity() {
    if (!_disposed) onDataChanged();
  }

  @override
  void onEnded(String words, {required bool hadConversation}) {
    kind = null;
    _chat = null;
    _call = null;
    _tellForm = false;
    lines.clear();
    inputEnabled = false;
    muted = false;
    status = words;
    _mover.stop();
    _watch.stop();
    if (hadConversation && !_disposed) onDataChanged(); // the assistant may have changed categories or goals
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    contexts.removeListener(_screenChanged);
    _mover.stop();
    _watch.stop();
    _chat?.hangUp();
    _call?.hangUp();
    _chat?.dispose();
    _formScripts.close();
    super.dispose();
  }
}

/// Which shared form to open, and how.
class FormOpening {
  const FormOpening.disputeLink(String this.link) : sessionId = null;
  const FormOpening.disputeSession(String this.sessionId) : link = null;

  final String? link; // the exact link the dispute assistant posted
  final String? sessionId; // the form the app opened itself (disputes/open)
}
