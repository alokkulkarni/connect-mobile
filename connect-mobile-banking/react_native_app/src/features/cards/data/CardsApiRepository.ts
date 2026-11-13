import { ApiTransport } from '../../../core/network/ApiTransport';
import { CardsRepository, CardsView, Dispute, DisputesRepository } from '../domain/cards';

export class CardsApiRepository implements CardsRepository {
  constructor(private readonly api: ApiTransport) {}

  cards(): Promise<CardsView> {
    return this.api.post<CardsView>('app/cards');
  }
}

export class DisputesApiRepository implements DisputesRepository {
  constructor(private readonly api: ApiTransport) {}

  async list(): Promise<Dispute[]> {
    return (await this.api.post<{ disputes: Dispute[] }>('disputes')).disputes || [];
  }

  async submit(disputeId: string): Promise<Dispute> {
    return (await this.api.post<{ dispute: Dispute }>('disputes/submit', { disputeId })).dispute;
  }
}
