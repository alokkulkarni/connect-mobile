import { ApiTransport } from '../../../core/network/ApiTransport';
import { fixtures } from '../../../core/fixtures';
import { PlaceEntry, PlacesRepository } from '../domain/places';
import { Transaction, TransactionFilter, TransactionPage, TransactionsRepository } from '../domain/transactions';

export class TransactionsApiRepository implements TransactionsRepository {
  constructor(private readonly api: ApiTransport) {}

  list(filter: TransactionFilter): Promise<TransactionPage> {
    const body: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(filter)) if (value !== undefined && value !== '') body[key] = value;
    return this.api.post<TransactionPage>('transactions', body);
  }

  async recategorise(transactionId: string, category: string): Promise<Transaction> {
    const reply = await this.api.post<{ transaction: Transaction }>('recategorise', { transactionId, category });
    return reply.transaction;
  }
}

// The illustrative places, bundled with the app (a backend could serve them later behind the same interface).
export class BundledPlacesRepository implements PlacesRepository {
  places(): PlaceEntry[] {
    return fixtures.merchantPlaces.places as PlaceEntry[];
  }
}
