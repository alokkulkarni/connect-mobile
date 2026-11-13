// The banking app's own contact routes, over whichever transport the session has.
import { ApiTransport } from '../../../core/network/ApiTransport';
import type { AssistantApi, CallStart, ChatStart, TranscriptReply } from '../domain/ports';
import type { PageFields } from '../domain/screenContext';

export class AssistantApiRepository implements AssistantApi {
  constructor(private readonly api: ApiTransport) {}

  startChat(fields: PageFields) {
    return this.api.post<ChatStart>('contact/chat', fields);
  }

  startCall(fields: PageFields) {
    return this.api.post<CallStart>('contact/call', fields);
  }

  returned(contactId: string) {
    return this.api.post<{ note: string; key: string }>('contact/returned', { contactId });
  }

  transcript(contactId: string) {
    return this.api.post<TranscriptReply>('contact/transcript', { contactId });
  }

  pageMoved(contactId: string, fields: PageFields) {
    return this.api.post('contact/page', { contactId, ...fields });
  }

  disputesLive(contactId: string) {
    return this.api.post<{ dispute: { disputeId: string } | null; formSent: boolean }>('disputes/live', { contactId });
  }

  disputesOpen(contactId: string, disputeId: string) {
    return this.api.post<{ sessionId: string }>('disputes/open', { contactId, disputeId });
  }
}
