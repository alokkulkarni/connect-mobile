// The app's screens and what each takes.
import { createNavigationContainerRef, NavigatorScreenParams } from '@react-navigation/native';
import type { HubView } from '../../features/money_hub/domain/moneyHub';
import type { Transaction } from '../../features/transactions/domain/transactions';

export type TabParams = {
  Home: undefined;
  Accounts: { account?: 'current' | 'savings' } | undefined;
  Cards: { paymentId?: string; tab?: 'payments' | 'disputes'; nonce?: number } | undefined;
  MoneyHub: { view?: HubView; nonce?: number } | undefined;
  More: undefined;
};

export type FormParams = { kind: 'mortgage' } | { kind: 'link'; url: string } | { kind: 'disputeSession'; sessionId: string };

export type RootParams = {
  Tabs: NavigatorScreenParams<TabParams>;
  Transactions: undefined;
  TransactionDetail: { transaction?: Transaction; transactionId?: string; nonce?: number };
  Mortgages: undefined;
  Help: undefined;
  Notifications: undefined;
  Settings: undefined;
  Form: FormParams;
};

export const navigationRef = createNavigationContainerRef<RootParams>();

export const TAB_ROUTES = new Set(['Home', 'Accounts', 'Cards', 'MoneyHub', 'More']);
