// What a screen tells the assistant (CONTRACT.md section 3). Only the page fields go to the server; who the
// customer is never does. The rest is shown in the app only.

export type PageFields = { page: string; view: string; stage: string; applicationId: string; paymentId: string };

export type ScreenContext = {
  page?: string; //          undefined on a screen with no assistant of its own (the forms WebView)
  view?: string;
  stage?: string;
  applicationId?: string;
  paymentId?: string;
  label: string; //           where the customer is, in words ("Money Hub · Expected")
  launcher: string; //        the launcher's words ("Ask about your money")
  draft?: string; //          words offered for the chat box, unsent
  screen: string; //          the route that published it (for push intents waiting on their screen)
};

export const HOME_CONTEXT: ScreenContext = { page: 'home', label: 'Home', launcher: 'Ask us anything', screen: 'Home' };

export const pageFields = (c: ScreenContext): PageFields => ({
  page: c.page || 'home',
  view: c.view || '',
  stage: c.stage || '',
  applicationId: c.applicationId || '',
  paymentId: c.paymentId || '',
});

// Two contexts are the same place for the assistant when these match (app.js pageKey).
export const pageKey = (c: ScreenContext): string =>
  [c.page || '', c.view || '', c.stage || '', c.applicationId || '', c.paymentId || ''].join('|');
