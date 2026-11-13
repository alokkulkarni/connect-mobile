import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/providers.dart';
import '../../../core/routing/form_opener.dart';
import '../../home/presentation/home_providers.dart';
import '../data/conversation_backend_impl.dart';
import '../data/native_call.dart';
import '../data/participant_service.dart';
import '../domain/call_session.dart';
import '../domain/chat_session.dart';
import 'assistant_controller.dart';
import 'screen_contexts.dart';

final screenContextsProvider = ChangeNotifierProvider<ScreenContexts>((ref) => ScreenContexts());

/// The assistant, wired to the real Participant Service, websocket, native call and microphone. A new session
/// (sign-in or sign-out) makes a new one; the old one ends its conversation as it goes.
final assistantControllerProvider = ChangeNotifierProvider<AssistantController>((ref) {
  final transport = ref.watch(transportProvider);
  const uuid = Uuid();
  final controller = AssistantController(
    backend: ConversationBackendImpl(transport),
    participant: HttpParticipantApi(),
    connect: WebSocketChatSocket.connect,
    media: ChimeCallMedia(),
    microphone: PermissionMicrophone(),
    contexts: ref.read(screenContextsProvider),
    newId: uuid.v4,
    talkAvailable: () => ref.read(homeSummaryProvider).value?.talk ?? false,
    disputePagesUrl: () => ref.read(homeSummaryProvider).value?.disputePagesUrl ?? '',
    onDataChanged: () => ref.read(dataVersionProvider.notifier).bump(),
    chatTimings: ChatTimings(heartbeat: appTimings.heartbeat, openerWait: appTimings.openerWait),
    callTimings: CallTimings(captionPoll: appTimings.captionPoll, connectTimeout: appTimings.callConnectTimeout),
    pageSettle: appTimings.pageSettle,
    disputeWatch: appTimings.disputeWatch,
  );
  controller.openForm = (opening) => openAssistantForm(ref, opening);
  return controller;
});
