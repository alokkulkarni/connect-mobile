// The customer's accounts, as the Home and Accounts screens show them (bankapp/home.py accounts, account_history).

export type AccountKind = 'current' | 'savings' | 'mortgage';

export type Account = {
  id: string;
  name: string;
  ending: string;
  kind: AccountKind;
  balance?: number;
  monthly?: number;
  note?: string;
};

// A movement in an account's list: the current account's payments, or the saver's transfers.
export type Movement = {
  date: string;
  merchantName: string;
  merchant: string;
  amount: number;
  category: string;
  in: boolean;
};

export type AccountsView = { asOf: string; accounts: Account[]; selected: 'current' | 'savings'; recent: Movement[] };

export interface AccountsRepository {
  accounts(which: 'current' | 'savings'): Promise<AccountsView>;
}

export const SAVINGS_NOTE = 'Money only moves between your savings and your current account.';

export const totalBalance = (accounts: Account[]): number =>
  accounts.filter((a) => a.kind !== 'mortgage').reduce((sum, a) => sum + (a.balance || 0), 0);
