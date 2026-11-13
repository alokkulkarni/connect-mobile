// Common questions: the web app's Help page, and a few more for the app. `go` names a screen the answer points to.

export type Faq = { q: string; a: string; go?: { label: string; screen: 'MoneyHub' | 'Cards' | 'Mortgages' | 'Notifications' | 'Settings' } };

export const FAQS: Faq[] = [
  {
    q: 'How do I see where my money goes?',
    a: "Open your Money Hub. It shows money in and out by month, what's expected, and your savings goals.",
    go: { label: 'Open Money Hub', screen: 'MoneyHub' },
  },
  {
    q: "I don't recognise a card payment",
    a: "Go to Cards, find the payment and choose Dispute. We'll ask a few questions and help you put it right.",
    go: { label: 'Go to Cards', screen: 'Cards' },
  },
  {
    q: 'Can I apply for a mortgage online?',
    a: 'Yes. Go to Mortgages. You can fill it in yourself or with our assistant.',
    go: { label: 'Go to Mortgages', screen: 'Mortgages' },
  },
  {
    q: 'Is the assistant a person?',
    a: "No. It's an AI assistant, labelled as one. Ask at any time to speak to one of our colleagues.",
  },
  {
    q: 'Does the assistant know which screen I am on?',
    a: "Yes. It's told which screen you're on (for example your Money Hub, a card payment you chose or Mortgages), so it can help with that straight away. It's never told anything you haven't opened yourself.",
  },
  {
    q: 'What happens when I tap a money alert?',
    a: "The app opens the screen the alert is about and starts a chat or call there, so the assistant already knows what it's about. You can end it at any time.",
    go: { label: 'See sample alerts', screen: 'Notifications' },
  },
  {
    q: 'Can I keep chatting if I leave the app?',
    a: 'Yes. A chat carries on when you come back, and a call carries on while you use other apps. Close the assistant to end it.',
  },
  {
    q: 'How do I change a payment’s category?',
    a: 'Open the payment from your transactions and choose Change category. Money in can only move to a money-in category, and money out to a money-out one.',
  },
  {
    q: 'How do I remove my details from this phone?',
    a: 'Go to Settings and choose Forget this device. Any conversation ends and your link is removed from this phone.',
    go: { label: 'Open Settings', screen: 'Settings' },
  },
];
