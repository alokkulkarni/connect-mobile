import 'screen_context.dart';

// The ports the assistant needs, with no framework or HTTP behind them here: the banking app's backend (which
// alone starts contacts and knows who the customer is), the Connect Participant Service, its websocket, the
// microphone and the native call. The data layer implements each.

class ChatStart {
  const ChatStart({required this.contactId, required this.participantToken, required this.region, required this.journey, required this.opener});

  final String contactId, participantToken, region, journey, opener;
}

class CallStart {
  const CallStart({
    required this.contactId,
    required this.participantToken,
    required this.region,
    required this.journey,
    required this.meeting,
    required this.attendee,
    required this.transcript,
  });

  final String contactId, participantToken, region, journey;
  final Map<String, dynamic> meeting, attendee; // StartWebRTCContact's ConnectionData, for the native call only
  final bool transcript; // whether captions can be read
}

class CaptionLine {
  const CaptionLine({required this.at, required this.who, required this.text});

  final String at, who, text;
}

class TranscriptReply {
  const TranscriptReply({this.lines = const [], this.ended = false, this.withPerson = false, this.unavailable = false});

  final List<CaptionLine> lines;
  final bool ended, withPerson, unavailable;
}

class ReturnNote {
  const ReturnNote({this.note = '', this.key = ''});

  final String note, key;
}

class LiveDispute {
  const LiveDispute({this.disputeId, this.formSent = false});

  final String? disputeId;
  final bool formSent;
}

/// The banking app's conversation routes (docs/CONTRACT.md section 2).
abstract interface class ConversationBackend {
  Future<ChatStart> startChat(ScreenContext context);
  Future<CallStart> startCall(ScreenContext context);
  Future<TranscriptReply> transcript(String contactId);
  Future<ReturnNote> returned(String contactId);
  Future<void> pageMoved(String contactId, ScreenContext context);
  Future<LiveDispute> disputesLive(String contactId);
  Future<String> disputesOpen(String contactId, String disputeId);
}

/// A failure with words written for the customer (the backend's own message, or ours).
class ConversationException implements Exception {
  const ConversationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The Connect Participant Service: `POST <base>/<path>` with `X-Amz-Bearer`. No AWS credentials.
abstract interface class ParticipantApi {
  Future<Map<String, dynamic>> post(String region, String path, String bearer, Map<String, dynamic> body);
}

/// The chat's websocket: frames in (text), frames out, and done when it closes.
abstract interface class ChatSocket {
  Stream<String> get frames;
  void send(String frame);
  Future<void> close();
}

typedef SocketConnector = Future<ChatSocket> Function(Uri url);

abstract interface class Microphone {
  /// Ask for the microphone. False when refused.
  Future<bool> request();
}

enum CallMediaEventType { connected, stopped, error }

class CallMediaEvent {
  const CallMediaEvent(this.type, {this.code, this.message});

  final CallMediaEventType type;
  final int? code; // the Chime status code, when stopped
  final String? message;
}

/// The native call (the Amazon Chime SDK on iOS and Android): join, mute, leave, and what happened.
abstract interface class CallMedia {
  Stream<CallMediaEvent> get events;
  Future<void> join(Map<String, dynamic> meeting, Map<String, dynamic> attendee);
  Future<void> setMuted(bool muted);
  Future<void> leave();
}

enum ConversationKind { chat, call }

enum Speaker { customer, assistant }

class ChatLine {
  const ChatLine(this.speaker, this.text, {this.disputeLink});

  final Speaker speaker;
  final String text;

  /// The dispute form's link, when the assistant posted it: shown as "Open the form here".
  final String? disputeLink;
}

/// What a chat or call tells the screen. One listener per conversation.
abstract interface class ConversationListener {
  void onStatus(String words);
  void onStarted(String contactId, String journey, ConversationKind kind);
  void onLine(ChatLine line);
  void onInputEnabled(bool enabled);
  void onMuted(bool muted);

  /// The assistant said something: it may have saved a goal or moved a payment.   [talk.js onActivity]
  void onAssistantActivity();

  /// The conversation is over (or never started). [hadConversation]: a contact was started.
  void onEnded(String words, {required bool hadConversation});
}

/// Words for the customer from any failure.
String customerWords(Object error, [String fallback = "We couldn't connect you just now. Try again in a minute."]) =>
    error is ConversationException ? error.message : fallback;
