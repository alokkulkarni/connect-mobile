// Everything the Home screen shows, in one call (app/home), plus whether chat and calls are on.
import { Account, Movement } from '../../accounts/domain/accounts';

export type HomeSummary = {
  firstName: string;
  asOf: string;
  accounts: Account[];
  recent: Movement[];
  cards: { type: string; ending: string; name: string }[];
  talk: boolean;
  verified: boolean;
  disputePagesUrl: string;
};

export interface HomeRepository {
  home(): Promise<HomeSummary>;
}

// "Good morning, James"
export function greeting(firstName: string, hour: number): string {
  const part = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  return firstName ? `${part}, ${firstName}` : part;
}
