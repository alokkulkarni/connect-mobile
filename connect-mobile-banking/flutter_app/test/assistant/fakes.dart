import 'dart:async';
import 'dart:convert';

import 'package:connect_banking/features/assistant/domain/conversation.dart';
import 'package:connect_banking/features/assistant/domain/screen_context.dart';

// Stand-ins for the assistant's ports: the backend, the Participant Service, the websocket, the microphone, the
// native call, and a listener that records what the screen would show.

class FakeBackend implements ConversationBackend {
  ChatStart chatStart = const ChatStart(contactId: 'c-1', participantToken: 'p-token', region: 'eu-west-2', journey: 'money_hub', opener: 'I\'m on my Money Hub page.');
  CallStart callStart = const CallStart(
    contactId: 'c-2',
    participantToken: 'p-token',
    region: 'eu-west-2',
    journey: 'home',
    meeting: {'MeetingId': 'm'},
    attendee: {'AttendeeId': 'a'},
    transcript: true,
  );
  ReturnNote note = const ReturnNote();
  TranscriptReply transcriptReply = const TranscriptReply();
  LiveDispute live = const LiveDispute();
  final List<ScreenContext> started = [];
  final List<(String, ScreenContext)> moves = [];
  int returnedCalls = 0, liveCalls = 0, openCalls = 0, transcriptCalls = 0;

  @override
  Future<ChatStart> startChat(ScreenContext context) async {
    started.add(context);
    return chatStart;
  }

  @override
  Future<CallStart> startCall(ScreenContext context) async {
    started.add(context);
    return callStart;
  }

  @override
  Future<TranscriptReply> transcript(String contactId) async {
    transcriptCalls++;
    return transcriptReply;
  }

  @override
  Future<ReturnNote> returned(String contactId) async {
    returnedCalls++;
    return note;
  }

  @override
  Future<void> pageMoved(String contactId, ScreenContext context) async => moves.add((contactId, context));

  @override
  Future<LiveDispute> disputesLive(String contactId) async {
    liveCalls++;
    return live;
  }

  @override
  Future<String> disputesOpen(String contactId, String disputeId) async {
    openCalls++;
    return 'session-123';
  }
}

class ParticipantCall {
  ParticipantCall(this.path, this.bearer, this.body);

  final String path, bearer;
  final Map<String, dynamic> body;
}

class FakeParticipant implements ParticipantApi {
  final List<ParticipantCall> calls = [];
  List<Map<String, dynamic>> transcript = [];

  List<ParticipantCall> called(String path) => calls.where((c) => c.path == path).toList();

  /// The words of every message sent.
  List<String> get sent => [for (final c in called('message')) c.body['Content'] as String];

  @override
  Future<Map<String, dynamic>> post(String region, String path, String bearer, Map<String, dynamic> body) async {
    calls.add(ParticipantCall(path, bearer, body));
    return switch (path) {
      'connection' => {
          'ConnectionCredentials': {'ConnectionToken': 'conn-token'},
          'Websocket': {'Url': 'wss://example.test/ws'},
        },
      'transcript' => {'Transcript': transcript},
      _ => <String, dynamic>{},
    };
  }
}

class FakeSocket implements ChatSocket {
  final _frames = StreamController<String>();
  final List<String> sentFrames = [];
  bool closed = false;

  @override
  Stream<String> get frames => _frames.stream;

  @override
  void send(String frame) => sentFrames.add(frame);

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _frames.close();
  }

  /// A chat item arriving on the socket, as Connect sends it.
  void item(Map<String, dynamic> item) => _frames.add(jsonEncode({'topic': 'aws/chat', 'content': jsonEncode(item)}));

  /// The server closing the socket.
  void drop() => close();
}

Map<String, dynamic> message(String id, String role, String content) =>
    {'Id': id, 'Type': 'MESSAGE', 'ParticipantRole': role, 'Content': content, 'ContentType': 'text/plain'};

class RecordingListener implements ConversationListener {
  final List<String> statuses = [];
  final List<ChatLine> lines = [];
  final List<bool> input = [];
  final List<bool> muted = [];
  final List<(String, bool)> ended = [];
  int activity = 0;
  String? contactId;

  String get status => statuses.isEmpty ? '' : statuses.last;

  @override
  void onStatus(String words) => statuses.add(words);

  @override
  void onStarted(String contactId, String journey, ConversationKind kind) => this.contactId = contactId;

  @override
  void onLine(ChatLine line) => lines.add(line);

  @override
  void onInputEnabled(bool enabled) => input.add(enabled);

  @override
  void onMuted(bool muted) => this.muted.add(muted);

  @override
  void onAssistantActivity() => activity++;

  @override
  void onEnded(String words, {required bool hadConversation}) => ended.add((words, hadConversation));
}

class FakeMicrophone implements Microphone {
  FakeMicrophone({this.granted = true});

  bool granted;

  @override
  Future<bool> request() async => granted;
}

class FakeCallMedia implements CallMedia {
  final _events = StreamController<CallMediaEvent>.broadcast();
  int joins = 0, leaves = 0;
  final List<bool> mutes = [];

  void emit(CallMediaEvent event) => _events.add(event);

  @override
  Stream<CallMediaEvent> get events => _events.stream;

  @override
  Future<void> join(Map<String, dynamic> meeting, Map<String, dynamic> attendee) async => joins++;

  @override
  Future<void> leave() async => leaves++;

  @override
  Future<void> setMuted(bool muted) async => mutes.add(muted);
}

const moneyHubOut = ScreenContext(page: 'money_hub', view: 'out', label: 'Money Hub · Money out', launcher: 'Ask about your money');
