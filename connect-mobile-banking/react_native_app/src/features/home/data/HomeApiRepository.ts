import { ApiTransport } from '../../../core/network/ApiTransport';
import { HomeRepository, HomeSummary } from '../domain/home';

export class HomeApiRepository implements HomeRepository {
  constructor(private readonly api: ApiTransport) {}

  async home(): Promise<HomeSummary> {
    const reply = await this.api.post<Partial<HomeSummary>>('app/home');
    return {
      firstName: reply.firstName || '',
      asOf: reply.asOf || '',
      accounts: reply.accounts || [],
      recent: reply.recent || [],
      cards: reply.cards || [],
      talk: Boolean(reply.talk),
      verified: Boolean(reply.verified),
      disputePagesUrl: reply.disputePagesUrl || '',
    };
  }
}
