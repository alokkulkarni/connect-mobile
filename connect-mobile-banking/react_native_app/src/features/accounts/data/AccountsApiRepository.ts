import { ApiTransport } from '../../../core/network/ApiTransport';
import { AccountsRepository, AccountsView } from '../domain/accounts';

export class AccountsApiRepository implements AccountsRepository {
  constructor(private readonly api: ApiTransport) {}

  accounts(which: 'current' | 'savings'): Promise<AccountsView> {
    return this.api.post<AccountsView>('app/accounts', { account: which });
  }
}
