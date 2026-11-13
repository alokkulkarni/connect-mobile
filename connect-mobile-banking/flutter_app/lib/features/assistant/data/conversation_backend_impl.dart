import '../../../core/network/api_transport.dart';
import '../domain/conversation.dart';
import '../domain/screen_context.dart';

// The banking app's conversation routes (contact/*, disputes/live, disputes/open) through the app's transport.
// The backend's own words become the domain's ConversationException.
class ConversationBackendImpl implements ConversationBackend {
  ConversationBackendImpl(this._api);

  final ApiTransport _api;

  Future<Map<String, dynamic>> _post(String route, Map<String, dynamic> body) async {
    try {
      return await _api.post(route, body);
    } on ApiException catch (error) {
      if (error.linkExpired) rethrow; // the app forgets the link and goes back to sign-in
      throw ConversationException(error.message);
    }
  }

  String _s(Map<String, dynamic> json, String key) => json[key] is String ? json[key] as String : '';

  @override
  Future<ChatStart> startChat(ScreenContext context) async {
    final r = await _post('contact/chat', context.toFields());
    return ChatStart(
      contactId: _s(r, 'contactId'),
      participantToken: _s(r, 'participantToken'),
      region: _s(r, 'region'),
      journey: _s(r, 'journey'),
      opener: _s(r, 'opener'),
    );
  }

  @override
  Future<CallStart> startCall(ScreenContext context) async {
    final r = await _post('contact/call', context.toFields());
    return CallStart(
      contactId: _s(r, 'contactId'),
      participantToken: _s(r, 'participantToken'),
      region: _s(r, 'region'),
      journey: _s(r, 'journey'),
      meeting: (r['meeting'] as Map?)?.cast<String, dynamic>() ?? const {},
      attendee: (r['attendee'] as Map?)?.cast<String, dynamic>() ?? const {},
      transcript: r['transcript'] == true,
    );
  }

  @override
  Future<TranscriptReply> transcript(String contactId) async {
    final r = await _post('contact/transcript', {'contactId': contactId});
    return TranscriptReply(
      lines: [
        for (final l in (r['lines'] as List? ?? const []).cast<Map<String, dynamic>>())
          CaptionLine(at: '${l['at'] ?? ''}', who: _s(l, 'who'), text: _s(l, 'text')),
      ],
      ended: r['ended'] == true,
      withPerson: r['withPerson'] == true,
      unavailable: r['unavailable'] == true,
    );
  }

  @override
  Future<ReturnNote> returned(String contactId) async {
    final r = await _post('contact/returned', {'contactId': contactId});
    return ReturnNote(note: _s(r, 'note'), key: _s(r, 'key'));
  }

  @override
  Future<void> pageMoved(String contactId, ScreenContext context) =>
      _post('contact/page', {'contactId': contactId, ...context.toFields()});

  @override
  Future<LiveDispute> disputesLive(String contactId) async {
    final r = await _post('disputes/live', {'contactId': contactId});
    final dispute = r['dispute'];
    return LiveDispute(
      disputeId: dispute is Map ? dispute['disputeId'] as String? : null,
      formSent: r['formSent'] == true,
    );
  }

  @override
  Future<String> disputesOpen(String contactId, String disputeId) async {
    final r = await _post('disputes/open', {'contactId': contactId, 'disputeId': disputeId});
    return _s(r, 'sessionId');
  }
}
