// The banking app's own replies for the sample customer, made by its own code (connect-mobile-banking/scripts/
// make_fixtures.py). Sample mode answers from these, so it returns exactly what Link mode does.
import appHome from './app_home.json';
import accountsCurrent from './app_accounts_current.json';
import accountsSavings from './app_accounts_savings.json';
import appCards from './app_cards.json';
import hub from './hub.json';
import transactionsP1 from './transactions_p1.json';
import transactionsP2 from './transactions_p2.json';
import transactionsP3 from './transactions_p3.json';
import disputes from './disputes.json';
import mortgageConfig from './mortgage_config.json';
import merchantPlaces from './merchant_places.json';

export const fixtures = {
  appHome,
  accountsCurrent,
  accountsSavings,
  appCards,
  hub,
  transactions: [...transactionsP1.transactions, ...transactionsP2.transactions, ...transactionsP3.transactions],
  disputes,
  mortgageConfig,
  merchantPlaces,
};
