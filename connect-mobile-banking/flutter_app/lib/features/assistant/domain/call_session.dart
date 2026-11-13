import 'dart:async';

import 'conversation.dart';
import 'screen_context.dart';

// A call with the assistant, ported from connect-banking-app/web/widget/talk.js (startCall, readTranscript,
// toggleMute, hangUp). docs/CONTRACT.md section 5, rules V1 to V9. Audio only: the native side (the Amazon Chime
// SDK) joins, mutes and leaves; this owns the sequence.

class CallTimings {
  const CallTimings({this.captionPoll = const Duration(seconds: 2), this.connectTimeout = const Duration(seconds: 25)});

  final Duration captionPoll;
  final Duration connectTimeout;
}

const cantConnectWords =
    "The call couldn't connect. A VPN or work network can block calls: try another network, or use Chat.";

class _CallLive {
  _CallLive(this.started);

  final CallStart started;
  StreamSubscription<CallMediaEvent>? events;
  Timer? captions;
  Timer? connecting;
  bool connected = false;
  bool reading = false;
  bool withPerson = false;
  bool muted = false;
}

class CallSession {
  CallSession({
    required this.backend,
    required this.participant,
    required this.media,
    required this.microphone,
    required this.listener,
    required this.newId,
    this.timings = const CallTimings(),
  });

  final ConversationBackend backend;
  final ParticipantApi participant;
  final CallMedia media;
  final Microphone microphone;
  final ConversationListener listener;
  final String Function() newId;
  final CallTimings timings;

  _CallLive? _live;
  final Set<String> _seen = {};

  bool get active => _live != null;
  String? get contactId => _live?.started.contactId;
  bool get muted => _live?.muted ?? false;

  Future<void> start(ScreenContext context) async {
    _seen.clear();
    listener.onStatus('Starting your call…');
    try {
      // V1: the microphone first, so a refusal costs nothing.
      if (!await microphone.request()) {
        _finish('To call, allow this app to use your microphone.');
        return;
      }
      final started = await backend.startCall(context); // V2
      final live = _live = _CallLive(started);
      listener.onStarted(started.contactId, started.journey, ConversationKind.call);
      live.events = media.events.listen((event) => _onMedia(live, event));
      if (started.transcript) {
        live.captions = Timer.periodic(timings.captionPoll, (_) => _readTranscript(live)); // V6
      }
      await media.join(started.meeting, started.attendee); // V3
      if (_live != live || live.connected) return;
      listener.onStatus('Connecting your call…');
      live.connecting = Timer(timings.connectTimeout, () {
        if (_live == live && !live.connected) hangUp(cantConnectWords); // V5
      });
    } catch (error) {
      _finish(customerWords(error, 'The call could not start.'));
    }
  }

  void _onMedia(_CallLive live, CallMediaEvent event) {
    if (_live != live) return;
    switch (event.type) {
      case CallMediaEventType.connected:
        live.connected = true;
        live.connecting?.cancel();
        listener.onStatus("Connected. Speak when you're ready${live.started.transcript ? "; what's said appears below" : ''}."
            ' Headphones give the clearest call.');
      case CallMediaEventType.stopped: // V9
        _finish(live.connected ? 'The call has ended.' : cantConnectWords);
      case CallMediaEventType.error:
        _finish(event.message ?? 'The call could not start.');
    }
  }

  // V6: new lines of the call's transcript, each shown once, oldest first.
  Future<void> _readTranscript(_CallLive live) async {
    if (_live != live || live.reading) return;
    live.reading = true;
    try {
      final said = await backend.transcript(live.started.contactId);
      if (_live != live) return;
      if (said.unavailable) live.captions?.cancel(); // this deployment can't read transcripts
      if (said.withPerson && !live.withPerson) {
        live.withPerson = true; // an adviser joined: they're heard as themselves
        listener.onStatus('A colleague has joined the call.');
      }
      for (final line in said.lines) {
        if (!_seen.add('${line.at}|${line.who}|${line.text}')) continue;
        listener.onLine(ChatLine(line.who == 'customer' ? Speaker.customer : Speaker.assistant, line.text));
      }
    } catch (_) {
      // try again on the next tick
    } finally {
      live.reading = false;
    }
  }

  /// V7.
  Future<void> toggleMute() async {
    final live = _live;
    if (live == null) return;
    live.muted = !live.muted;
    listener.onMuted(live.muted);
    try {
      await media.setMuted(live.muted);
    } catch (_) {
      live.muted = !live.muted;
      listener.onMuted(live.muted);
    }
  }

  /// V8: leave properly, so Connect ends the contact at once.
  Future<void> hangUp([String? words]) async {
    final live = _live;
    if (live == null) return;
    try {
      final joined = await participant.post(live.started.region, 'connection', live.started.participantToken, {
        'Type': ['CONNECTION_CREDENTIALS'],
      });
      final token = (joined['ConnectionCredentials'] as Map)['ConnectionToken'] as String;
      await participant.post(live.started.region, 'disconnect', token, {'ClientToken': newId()});
    } catch (_) {
      // the contact may already have ended
    }
    if (_live != live) return;
    _finish(words ?? 'You ended the call.');
  }

  void _finish(String words) {
    final live = _live;
    _live = null;
    if (live != null) {
      live.captions?.cancel();
      live.connecting?.cancel();
      live.events?.cancel();
      media.leave().catchError((_) {});
    }
    _seen.clear();
    listener.onEnded(words, hadConversation: live != null);
  }
}
