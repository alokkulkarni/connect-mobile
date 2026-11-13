// The composition root: one container per signed-in session, wiring each feature's data layer to its domain
// interfaces. Nothing else constructs repositories, transports or the assistant.
import { ApiTransport } from '../core/network/ApiTransport';
import { LinkTransport } from '../core/network/LinkTransport';
import { SampleTransport } from '../core/network/SampleTransport';
import { realTimers, uuid } from '../core/util/timers';
import { AccountsApiRepository } from '../features/accounts/data/AccountsApiRepository';
import { AccountsRepository } from '../features/accounts/domain/accounts';
import { AssistantApiRepository } from '../features/assistant/data/AssistantApiRepository';
import { NativeCallBridge, PlatformMicrophone } from '../features/assistant/data/NativeCallBridge';
import { ParticipantHttpClient, webSocketFactory } from '../features/assistant/data/participant';
import { AssistantController } from '../features/assistant/domain/assistantController';
import { CardsApiRepository, DisputesApiRepository } from '../features/cards/data/CardsApiRepository';
import { CardsRepository, DisputesRepository } from '../features/cards/domain/cards';
import { HomeApiRepository } from '../features/home/data/HomeApiRepository';
import { HomeRepository } from '../features/home/domain/home';
import { MoneyHubApiRepository } from '../features/money_hub/data/MoneyHubApiRepository';
import { MoneyHubRepository } from '../features/money_hub/domain/moneyHub';
import { MortgagesApiRepository } from '../features/mortgages/data/MortgagesApiRepository';
import { MortgagesRepository } from '../features/mortgages/domain/mortgages';
import { Session } from '../features/session/domain/session';
import { BundledPlacesRepository, TransactionsApiRepository } from '../features/transactions/data/TransactionsApiRepository';
import { PlacesRepository } from '../features/transactions/domain/places';
import { TransactionsRepository } from '../features/transactions/domain/transactions';

export type Container = {
  session: Session;
  transport: ApiTransport;
  home: HomeRepository;
  accounts: AccountsRepository;
  transactions: TransactionsRepository;
  places: PlacesRepository;
  cards: CardsRepository;
  disputes: DisputesRepository;
  moneyHub: MoneyHubRepository;
  mortgages: MortgagesRepository;
  assistant: AssistantController;
};

export function createContainer(session: Session, onExpired: () => void): Container {
  const transport: ApiTransport = session.mode === 'link' ? new LinkTransport(session.origin, session.secret, onExpired) : new SampleTransport();
  return {
    session,
    transport,
    home: new HomeApiRepository(transport),
    accounts: new AccountsApiRepository(transport),
    transactions: new TransactionsApiRepository(transport),
    places: new BundledPlacesRepository(),
    cards: new CardsApiRepository(transport),
    disputes: new DisputesApiRepository(transport),
    moneyHub: new MoneyHubApiRepository(transport),
    mortgages: new MortgagesApiRepository(transport),
    assistant: new AssistantController({
      api: new AssistantApiRepository(transport),
      participant: new ParticipantHttpClient(),
      sockets: webSocketFactory,
      bridge: new NativeCallBridge(),
      microphone: new PlatformMicrophone(),
      timers: realTimers,
      uuid,
    }),
  };
}
