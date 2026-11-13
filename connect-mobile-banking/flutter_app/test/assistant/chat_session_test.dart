import 'dart:convert';

import 'package:connect_banking/features/assistant/domain/chat_session.dart';
import 'package:connect_banking/features/assistant/domain/conversation.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// The chat rules of docs/CONTRACT.md section 4 (C1 to C14), as talk.js has them.
void main() {
  late FakeBackend backend;
  late FakeParticipant participant;
  late List<FakeSocket> sockets;
  late RecordingListener listener;
  var ids = 0;

  ChatSession session({String disputePagesUrl = ''}) => ChatSession(
        backend: backend,
        participant: participant,
        connect: (url) async {
          final socket = FakeSocket();
          sockets.add(socket);
          return socket;
        },
        listener: listener,
        newId: () => 'id-${ids++}',
        disputePagesUrl: disputePagesUrl,
      );

  setUp(() {
    backend = FakeBackend();
    participant = FakeParticipant();
    sockets = [];
    listener = RecordingListener();
  });

  test('C1 to C4: starts from the screen, joins with WEBSOCKET + CONNECTION_CREDENTIALS, subscribes, reads the transcript', () {
    fakeAsync((async) {
      session().start(moneyHubOut);
      async.flushMicrotasks();
      expect(backend.started.single.view, 'out');
      final connection = participant.called('connection').single;
      expect(connection.bearer, 'p-token');
      expect(connection.body['Type'], ['WEBSOCKET', 'CONNECTION_CREDENTIALS']);
      expect(jsonDecode(sockets.single.sentFrames.first), {
        'topic': 'aws/subscribe',
        'content': {'topics': ['aws/chat']},
      });
      final transcript = participant.called('transcript').single;
      expect(transcript.bearer, 'conn-token');
      expect(transcript.body, {'MaxResults': 100, 'ScanDirection': 'BACKWARD', 'SortOrder': 'ASCENDING'});
      expect(listener.status, 'Connecting you to our assistant…');
      expect(listener.input.last, isFalse);
      async.elapse(const Duration(seconds: 10));
      expect(sockets.single.sentFrames.where((f) => f.contains('aws/heartbeat')), hasLength(1));
    });
  });

  test('C7: the opener goes once, on the first non-customer message (even blank), then the input opens', () {
    fakeAsync((async) {
      session().start(moneyHubOut);
      async.flushMicrotasks();
      sockets.single.item(message('m1', 'SYSTEM', ' '));
      async.flushMicrotasks();
      expect(participant.sent, ["I'm on my Money Hub page."]);
      expect(listener.input.last, isTrue);
      expect(listener.status, 'Connected.');
      sockets.single.item(message('m2', 'AGENT', 'Hello James'));
      async.flushMicrotasks();
      expect(participant.sent, hasLength(1));
    });
  });

  test('C7: with no message, the opener goes after 20 s', () {
    fakeAsync((async) {
      session().start(moneyHubOut);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 19));
      expect(participant.sent, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(participant.sent, ["I'm on my Money Hub page."]);
      expect(listener.input.last, isTrue);
    });
  });

  test('C5, C6: items are shown once; return notes are never shown; emphasis is plain', () {
    fakeAsync((async) {
      participant.transcript = [message('t1', 'AGENT', 'You spent **£32.45** at Amazon')];
      session().start(moneyHubOut);
      async.flushMicrotasks();
      sockets.single.item(message('t1', 'AGENT', 'You spent **£32.45** at Amazon')); // already seen in the transcript
      sockets.single.item(message('c1', 'CUSTOMER', 'Back from card dispute: They want help with something else.'));
      sockets.single.item(message('c2', 'CUSTOMER', 'Thanks'));
      async.flushMicrotasks();
      expect([for (final l in listener.lines) l.text], ['You spent £32.45 at Amazon', 'Thanks']);
      expect(listener.lines.first.speaker, Speaker.assistant);
      expect(listener.lines.last.speaker, Speaker.customer);
      expect(listener.activity, 1);
    });
  });

  test('C8: a blank message after the opener asks for a return note and sends it once per key', () {
    fakeAsync((async) {
      session().start(moneyHubOut);
      async.flushMicrotasks();
      sockets.single.item(message('m1', 'SYSTEM', '')); // the opener
      async.flushMicrotasks();
      backend.note = const ReturnNote(note: 'Back from card dispute: They want help with something else.', key: 'k1');
      sockets.single.item(message('m2', 'SYSTEM', '')); // ARIA's bot block started again
      async.flushMicrotasks();
      sockets.single.item(message('m3', 'SYSTEM', ''));
      async.flushMicrotasks();
      expect(backend.returnedCalls, 2);
      expect(participant.sent.where((w) => w.startsWith('Back from card dispute:')), hasLength(1));
      backend.note = const ReturnNote(note: 'Back from mortgage application: Done.', key: 'k2');
      sockets.single.item(message('m4', 'SYSTEM', ''));
      async.flushMicrotasks();
      expect(participant.sent.last, 'Back from mortgage application: Done.');
      expect(listener.lines, isEmpty); // none of it is shown
    });
  });

  test('C9: the dispute form link in an assistant message is offered as "Open the form here"', () {
    fakeAsync((async) {
      session(disputePagesUrl: 'https://disputes.example').start(moneyHubOut);
      async.flushMicrotasks();
      sockets.single.item(message('m1', 'AGENT', 'Here is your form: https://disputes.example/form#k=abcdefghijklmnop1234 thanks'));
      sockets.single.item(message('m2', 'AGENT', 'Elsewhere: https://other.example/form#k=abcdefghijklmnop1234'));
      async.flushMicrotasks();
      expect(listener.lines.first.disputeLink, 'https://disputes.example/form#k=abcdefghijklmnop1234');
      expect(listener.lines.last.disputeLink, isNull);
    });
  });

  test('C10: the chat-ended event ends the chat', () {
    fakeAsync((async) {
      final chat = session()..start(moneyHubOut);
      async.flushMicrotasks();
      sockets.single.item({'Id': 'e1', 'Type': 'EVENT', 'ContentType': 'application/vnd.amazonaws.connect.event.chat.ended'});
      async.flushMicrotasks();
      expect(listener.ended.single, ('The chat has ended.', true));
      expect(chat.active, isFalse);
      expect(sockets.single.closed, isTrue);
    });
  });

  test('C13: a socket dropped in the background reconnects on return; in the foreground it ends the chat', () {
    fakeAsync((async) {
      final chat = session()..start(moneyHubOut);
      async.flushMicrotasks();
      chat.setForeground(false);
      sockets.single.drop();
      async.flushMicrotasks();
      expect(listener.ended, isEmpty);
      chat.setForeground(true);
      async.flushMicrotasks();
      expect(participant.called('connection'), hasLength(2));
      expect(sockets, hasLength(2));
      sockets.last.drop();
      async.flushMicrotasks();
      expect(listener.ended.single.$1, 'The chat has ended.');
    });
  });

  test('C11, C12: sending and hanging up', () {
    fakeAsync((async) {
      final chat = session()..start(moneyHubOut);
      async.flushMicrotasks();
      chat.send('  Where does my money go?  ');
      async.flushMicrotasks();
      expect(participant.sent.last, 'Where does my money go?');
      chat.hangUp();
      async.flushMicrotasks();
      expect(participant.called('disconnect').single.bearer, 'conn-token');
      expect(listener.ended.single, ('You ended the chat.', true));
    });
  });

  test('a start the backend refuses ends with its words and no conversation', () {
    fakeAsync((async) {
      final failing = _RefusingBackend();
      ChatSession(
        backend: failing,
        participant: participant,
        connect: (_) async => FakeSocket(),
        listener: listener,
        newId: () => 'x',
      ).start(moneyHubOut);
      async.flushMicrotasks();
      expect(listener.ended.single, ("Calls and chats aren't set up for this app yet.", false));
    });
  });
}

class _RefusingBackend extends FakeBackend {
  @override
  Future<ChatStart> startChat(context) async => throw const ConversationException("Calls and chats aren't set up for this app yet.");
}
