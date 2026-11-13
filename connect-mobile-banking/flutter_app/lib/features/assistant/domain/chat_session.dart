import 'dart:async';
import 'dart:convert';

import 'chat_rules.dart';
import 'conversation.dart';
import 'screen_context.dart';

// A chat with the assistant, ported from connect-banking-app/web/widget/talk.js (startChat, onChatItem,
// sendOpener, sendReturnNote, sendChat, hangUp, finish). docs/CONTRACT.md section 4, rules C1 to C15.
//
// The backend starts the contact (it alone knows who this is); this joins it through the Connect Participant
// Service and its websocket. The participant and connection tokens live only in this object's memory.

class ChatTimings {
  const ChatTimings({this.heartbeat = const Duration(seconds: 10), this.openerWait = const Duration(seconds: 20)});

  final Duration heartbeat;
  final Duration openerWait;
}

class _Live {
  _Live(this.started);

  final ChatStart started;
  String? connectionToken;
  ChatSocket? socket;
  StreamSubscription<String>? frames;
  Timer? heartbeat;
  Timer? openerTimer;
  bool opened = false; // the opener has been handled; the customer may type
  bool askingReturn = false;
  String returnKey = '';
}

class ChatSession {
  ChatSession({
    required this.backend,
    required this.participant,
    required this.connect,
    required this.listener,
    required this.newId,
    this.disputePagesUrl = '',
    this.timings = const ChatTimings(),
  });

  final ConversationBackend backend;
  final ParticipantApi participant;
  final SocketConnector connect;
  final ConversationListener listener;
  final String Function() newId;
  final String disputePagesUrl;
  final ChatTimings timings;

  _Live? _live;
  final Set<String> _seen = {};
  bool _foreground = true;

  bool get active => _live != null;
  String? get contactId => _live?.started.contactId;

  /// C1: start a chat from this screen.
  Future<void> start(ScreenContext context) async {
    _seen.clear();
    listener.onStatus('Connecting you…');
    try {
      final started = await backend.startChat(context);
      final live = _live = _Live(started);
      listener.onStarted(started.contactId, started.journey, ConversationKind.chat);
      await _join(live);
    } catch (error) {
      _finish(customerWords(error));
    }
  }

  // C2 to C4: the connection, the websocket and anything said before it was listening.
  Future<void> _join(_Live live) async {
    final joined = await participant.post(live.started.region, 'connection', live.started.participantToken, {
      'Type': ['WEBSOCKET', 'CONNECTION_CREDENTIALS'], // no ConnectParticipant: that's for streaming and agents
    });
    if (_live != live) return;
    final token = (joined['ConnectionCredentials'] as Map?)?['ConnectionToken'] as String?;
    final url = (joined['Websocket'] as Map?)?['Url'] as String?;
    if (token == null || url == null) {
      throw const ConversationException("We couldn't connect the conversation. Please try again.");
    }
    live.connectionToken = token;
    final socket = await connect(Uri.parse(url));
    if (_live != live) {
      await socket.close();
      return;
    }
    live.socket = socket;
    live.frames = socket.frames.listen(_onFrame, onDone: () => _socketClosed(live, socket), onError: (_) {});
    socket.send(jsonEncode({
      'topic': 'aws/subscribe',
      'content': {'topics': ['aws/chat']},
    }));
    live.heartbeat?.cancel();
    live.heartbeat = Timer.periodic(timings.heartbeat, (_) => socket.send(jsonEncode({'topic': 'aws/heartbeat'})));
    if (!live.opened) {
      listener.onStatus('Connecting you to our assistant…');
      listener.onInputEnabled(false);
    }
    // The latest 100, oldest first (FORWARD needs a StartPosition, and Connect refused it with a 400).
    Map<String, dynamic> transcript;
    try {
      transcript = await participant.post(live.started.region, 'transcript', token,
          {'MaxResults': 100, 'ScanDirection': 'BACKWARD', 'SortOrder': 'ASCENDING'});
    } catch (_) {
      transcript = const {};
    }
    for (final item in (transcript['Transcript'] as List? ?? const [])) {
      if (_live != live) return;
      if (item is Map<String, dynamic>) handleItem(item);
    }
    if (_live == live && !live.opened && live.openerTimer == null) {
      live.openerTimer = Timer(timings.openerWait, _sendOpener);
    }
  }

  void _onFrame(String data) {
    try {
      final frame = jsonDecode(data);
      if (frame is! Map || frame['topic'] != 'aws/chat' || frame['content'] is! String) return;
      final item = jsonDecode(frame['content'] as String);
      if (item is Map<String, dynamic>) handleItem(item);
    } catch (_) {
      // not a chat item
    }
  }

  /// C5 to C10: one chat item, from the socket or the transcript.
  void handleItem(Map<String, dynamic> item) {
    final live = _live;
    if (live == null) return;
    final id = item['Id'] as String?;
    if (id != null && !_seen.add(id)) return;
    final type = item['Type'];
    if (type == 'MESSAGE') {
      final role = item['ParticipantRole'] as String? ?? '';
      final content = item['Content'] as String? ?? '';
      final customer = role == 'CUSTOMER';
      if (customer && isReturnNote(content)) return; // ours, not theirs
      if (content.trim().isNotEmpty) {
        listener.onLine(ChatLine(customer ? Speaker.customer : Speaker.assistant, plain(content),
            disputeLink: customer ? null : disputeLinkIn(content, disputePagesUrl)));
        if (!customer) listener.onAssistantActivity();
      }
      if (!customer) {
        if (live.opened && content.trim().isEmpty) _sendReturnNote(); // ARIA's bot block started again
        _sendOpener(); // ARIA is listening now
      }
    }
    if (type == 'EVENT' && item['ContentType'] == chatEndedEvent) _finish('The chat has ended.');
  }

  // C7: the customer's first words, worded by the server for the screen, once ARIA is listening.
  void _sendOpener() {
    final live = _live;
    final token = live?.connectionToken;
    if (live == null || live.opened || token == null) return;
    live.opened = true;
    live.openerTimer?.cancel();
    if (live.started.opener.isNotEmpty) {
      participant
          .post(live.started.region, 'message', token,
              {'ContentType': 'text/plain', 'ClientToken': newId(), 'Content': live.started.opener})
          .catchError((Object error) {
        listener.onStatus(customerWords(error));
        return const <String, dynamic>{};
      });
    }
    listener.onInputEnabled(true);
    listener.onStatus('Connected.');
  }

  // C8: back to ARIA from an assistant: give her the note as a message, once per return.
  Future<void> _sendReturnNote() async {
    final live = _live;
    final token = live?.connectionToken;
    if (live == null || live.askingReturn || token == null) return;
    live.askingReturn = true;
    try {
      final back = await backend.returned(live.started.contactId);
      if (_live == live && back.note.isNotEmpty && back.key != live.returnKey) {
        live.returnKey = back.key;
        await participant.post(live.started.region, 'message', token,
            {'ContentType': 'text/plain', 'Content': back.note, 'ClientToken': newId()});
      }
    } catch (_) {
      // ARIA still answers the customer's next message
    }
    live.askingReturn = false;
  }

  /// C11: the customer's own words.
  Future<void> send(String words) async {
    final live = _live;
    final token = live?.connectionToken;
    final text = words.trim();
    if (live == null || token == null || text.isEmpty) return;
    try {
      await participant.post(live.started.region, 'message', token, {'ContentType': 'text/plain', 'Content': text, 'ClientToken': newId()});
    } catch (error) {
      listener.onStatus(customerWords(error));
    }
  }

  /// C12: leave properly, so Connect ends the contact rather than waiting for a timeout.
  Future<void> hangUp([String? words]) async {
    final live = _live;
    if (live == null) return;
    try {
      final token = live.connectionToken ??
          ((await participant.post(live.started.region, 'connection', live.started.participantToken, {
            'Type': ['CONNECTION_CREDENTIALS'],
          }))['ConnectionCredentials'] as Map)['ConnectionToken'] as String;
      await participant.post(live.started.region, 'disconnect', token, {'ClientToken': newId()});
    } catch (_) {
      // the contact may already have ended
    }
    if (_live != live) return;
    _finish(words ?? 'You ended the chat.');
  }

  // C10, C13: the socket closed. In the foreground the chat has ended; in the background it will reconnect.
  void _socketClosed(_Live live, ChatSocket socket) {
    if (_live != live || live.socket != socket) return;
    live.socket = null;
    live.heartbeat?.cancel();
    if (_foreground) _finish('The chat has ended.');
  }

  /// C13: the app moved to the foreground or the background. Coming back reconnects a dropped chat.
  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    final live = _live;
    if (!foreground || live == null || live.socket != null || live.connectionToken == null) return;
    try {
      await _join(live);
    } catch (error) {
      if (_live == live) _finish(customerWords(error));
    }
  }

  // C14: a finished conversation leaves only a one-line note of how it ended.
  void _finish(String words) {
    final live = _live;
    _live = null;
    if (live != null) {
      live.heartbeat?.cancel();
      live.openerTimer?.cancel();
      live.frames?.cancel();
      live.socket?.close();
    }
    _seen.clear();
    listener.onEnded(words, hadConversation: live != null);
  }

  /// Ends everything without telling Connect (the app is closing).
  void dispose() {
    final live = _live;
    _live = null;
    live?.heartbeat?.cancel();
    live?.openerTimer?.cancel();
    live?.frames?.cancel();
    live?.socket?.close();
  }
}
