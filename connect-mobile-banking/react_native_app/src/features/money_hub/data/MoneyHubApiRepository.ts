import { ApiTransport } from '../../../core/network/ApiTransport';
import { MoneyHub, MoneyHubRepository, NewGoal } from '../domain/moneyHub';

export class MoneyHubApiRepository implements MoneyHubRepository {
  constructor(private readonly api: ApiTransport) {}

  hub(): Promise<MoneyHub> {
    return this.api.post<MoneyHub>('hub');
  }

  async saveGoal(goal: NewGoal): Promise<void> {
    await this.api.post('goal', goal);
  }

  async deleteGoal(name: string): Promise<void> {
    await this.api.post('goal/delete', { name });
  }
}
