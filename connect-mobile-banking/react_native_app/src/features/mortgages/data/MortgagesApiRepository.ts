import { ApiTransport } from '../../../core/network/ApiTransport';
import { MortgagesRepository, Product } from '../domain/mortgages';

export class MortgagesApiRepository implements MortgagesRepository {
  constructor(private readonly api: ApiTransport) {}

  async products(): Promise<Product[]> {
    return (await this.api.post<{ products: Product[] }>('mortgage/config')).products || [];
  }
}
