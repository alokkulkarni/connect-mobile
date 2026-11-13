import 'package:connect_banking/features/assistant/domain/call_session.dart';
import 'package:connect_banking/features/assistant/domain/conversation.dart';
import 'package:connect_banking/features/assistant/domain/following.dart';
import 'package:connect_banking/features/assistant/domain/form_bridge.dart';
import 'package:connect_banking/features/assistant/domain/screen_context.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

// Calls (docs/CONTRACT.md section 5), page moves and the dispute watch (section 6), and the form bridge (section 9).
void main() {
  group('call', () {
    late FakeBackend backend;
    late FakeParticipant participant;
    late FakeCallMedia media;
    late RecordingListener listener;

    CallSession call({bool microphone = true}) => CallSession(
          backend: backend,
          participant: participant,
          media: media,
          microphone: FakeMicrophone(granted: microphone),
          listener: listener,
          newId: () => 'id',
        );

    setUp(() {
      backend = FakeBackend();
      participant = FakeParticipant();
      media = FakeCallMedia();
      listener = RecordingListener();
    });

    test('V1: a refused microphone costs nothing', () {
      fakeAsync((async) {
        call(microphone: false).start(moneyHubOut);
        async.flushMicrotasks();
        expect(backend.started, isEmpty);
        expect(listener.ended.single, ('To call, allow this app to use your microphone.', false));
      });
    });

    test('V3, V6: joins, says when connected, shows captions once, notices a colleague', () {
      fakeAsync((async) {
        call().start(moneyHubOut);
        async.flushMicrotasks();
        expect(media.joins, 1);
        expect(listener.status, 'Connecting your call…');
        media.emit(const CallMediaEvent(CallMediaEventType.connected));
        async.flushMicrotasks();
        expect(listener.status, startsWith("Connected. Speak when you're ready; what's said appears below."));
        backend.transcriptReply = const TranscriptReply(lines: [
          CaptionLine(at: '1', who: 'assistant', text: 'Hello James'),
          CaptionLine(at: '2', who: 'customer', text: 'Hi'),
        ]);
        async.elapse(const Duration(seconds: 2));
        backend.transcriptReply = const TranscriptReply(withPerson: true, lines: [CaptionLine(at: '1', who: 'assistant', text: 'Hello James')]);
        async.elapse(const Duration(seconds: 2));
        expect([for (final l in listener.lines) l.text], ['Hello James', 'Hi']);
        expect(listener.lines.last.speaker, Speaker.customer);
        expect(listener.status, 'A colleague has joined the call.');
      });
    });

    test('V5: not connected within 25 s hangs up properly and says why', () {
      fakeAsync((async) {
        call().start(moneyHubOut);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 25));
        expect(participant.called('connection').single.body['Type'], ['CONNECTION_CREDENTIALS']);
        expect(participant.called('disconnect').single.bearer, 'conn-token');
        expect(media.leaves, 1);
        expect(listener.ended.single.$1, cantConnectWords);
      });
    });

    test('V7, V9: mute follows; stopping after connecting ends the call', () {
      fakeAsync((async) {
        final c = call()..start(moneyHubOut);
        async.flushMicrotasks();
        media.emit(const CallMediaEvent(CallMediaEventType.connected));
        async.flushMicrotasks();
        c.toggleMute();
        async.flushMicrotasks();
        expect(media.mutes, [true]);
        expect(listener.muted, [true]);
        media.emit(const CallMediaEvent(CallMediaEventType.stopped, code: 0));
        async.flushMicrotasks();
        expect(listener.ended.single, ('The call has ended.', true));
      });
    });
  });

  group('page moves', () {
    const cards = ScreenContext(page: 'cards', label: 'Cards', launcher: 'Help with a payment');
    const help = ScreenContext(page: 'help', label: 'Help', launcher: 'Ask us anything');

    test('a screen kept for 1.5 s is told once; never the starting screen; only the last of quick moves', () {
      fakeAsync((async) {
        final told = <String>[];
        var current = moneyHubOut;
        final mover = PageMover(tell: (_, c) async => told.add(c.key))..begin('c-1', moneyHubOut);
        mover.changed(() => current); // still where it started
        async.elapse(const Duration(seconds: 2));
        expect(told, isEmpty);
        current = cards;
        mover.changed(() => current);
        async.elapse(const Duration(milliseconds: 1400));
        expect(told, isEmpty);
        async.elapse(const Duration(milliseconds: 100));
        expect(told, [cards.key]);
        mover.changed(() => current); // the same again
        async.elapse(const Duration(seconds: 2));
        expect(told, hasLength(1));
        current = help;
        mover.changed(() => current);
        async.elapse(const Duration(milliseconds: 500));
        current = moneyHubOut;
        mover.changed(() => current);
        async.elapse(const Duration(seconds: 2));
        expect(told, [cards.key, moneyHubOut.key]);
        mover.stop();
        current = help;
        mover.changed(() => current);
        async.elapse(const Duration(seconds: 2));
        expect(told, hasLength(2));
      });
    });
  });

  group('dispute watch', () {
    test('opens the form once, then stops looking', () {
      fakeAsync((async) {
        final backend = FakeBackend();
        final opened = <String>[];
        final watch = DisputeWatch(backend: backend, onFormSent: opened.add)..start('c-1');
        async.elapse(const Duration(seconds: 8));
        expect(backend.liveCalls, 2);
        expect(opened, isEmpty);
        backend.live = const LiveDispute(disputeId: 'DSP-1', formSent: true);
        async.elapse(const Duration(seconds: 4));
        expect(opened, ['session-123']);
        async.elapse(const Duration(seconds: 20));
        expect(backend.openCalls, 1);
        expect(backend.liveCalls, 3);
        watch.stop();
      });
    });

    test('the chat\'s own link counts as the once', () {
      fakeAsync((async) {
        final backend = FakeBackend()..live = const LiveDispute(disputeId: 'DSP-1', formSent: true);
        final opened = <String>[];
        DisputeWatch(backend: backend, onFormSent: opened.add)
          ..start('c-1')
          ..markOpened();
        async.elapse(const Duration(seconds: 12));
        expect(opened, isEmpty);
        expect(backend.openCalls, 0);
      });
    });
  });

  group('form bridge', () {
    test('accepts only a well-formed mortgage call request', () {
      final call = mortgageCallFromBridge('{"applicationId":"MA-ABCD2345","stage":"property_loan"}');
      expect(call?.page, 'mortgage');
      expect(call?.stage, 'property_loan');
      expect(mortgageCallFromBridge('{"applicationId":"MA-ABCD2345","stage":"anything"}'), isNull);
      expect(mortgageCallFromBridge('{"applicationId":"MA-I0000000","stage":"about_you"}'), isNull);
      expect(mortgageCallFromBridge('not json'), isNull);
    });

    test('app → page events carry only checked values', () {
      expect(mortgageCallStartedScript('3f2a9c1e-1d2b-4c3d-8e9f-0a1b2c3d4e5f'), contains("'mortgage:call-started'"));
      expect(mortgageCallStartedScript('"); alert(1); ("'), isEmpty);
      expect(disputeOpenScript('session-123'), contains("'dispute:open'"));
      expect(disputeOpenScript('<script>'), isEmpty);
    });
  });
}
