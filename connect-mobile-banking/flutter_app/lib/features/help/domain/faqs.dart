// Common questions: the internet banking web app's Help page (connect-banking-app/web/index.html t-help), and a few
// more for the app. Each may point to a screen.

class Faq {
  const Faq(this.question, this.answer, {this.screen, this.screenLabel});

  final String question;
  final String answer;
  final String? screen; // an app location, for example /money-hub/out
  final String? screenLabel;
}

const faqs = <Faq>[
  Faq('How do I see where my money goes?',
      'Open your Money Hub. It shows money in and out by month, what\'s expected, and your savings goals.',
      screen: '/money-hub/out', screenLabel: 'Open Money Hub'),
  Faq("I don't recognise a card payment",
      'Go to Cards, find the payment and choose Dispute. We\'ll ask a few questions and help you put it right.',
      screen: '/cards', screenLabel: 'Go to Cards'),
  Faq('Can I apply for a mortgage online?',
      'Yes. Go to Mortgages. You can fill it in yourself or with our assistant.',
      screen: '/more/mortgages', screenLabel: 'Go to Mortgages'),
  Faq('Is the assistant a person?',
      'No. It\'s an AI assistant, labelled as one. Ask at any time to speak to one of our colleagues.'),
  Faq('Does the assistant know which screen I\'m on?',
      'Yes. When you chat or call, it\'s told which screen you started on, such as your Money Hub or a card payment, '
          'and when you move to another screen. It\'s never told anything you haven\'t opened.'),
  Faq('Can I keep using the app during a call?',
      'Yes. Minimise the assistant and carry on: the call keeps going, and the assistant follows the screens you open.'),
  Faq('Why did a notification open a chat?',
      'Notifications about your money, such as an unusual payment or a low balance, can open the right screen and start '
          'a chat there, so the assistant already knows what it\'s about. You can end the chat at any time.',
      screen: '/more/notifications', screenLabel: 'See notifications'),
  Faq('How do I save for something?',
      'In Money Hub, open Goals and add a goal with an amount and a date. We\'ll show what to put aside each month.',
      screen: '/money-hub/goals', screenLabel: 'Open Goals'),
  Faq('How do I stop this phone showing my banking?',
      'Go to More, then Settings, and choose Forget this device. You\'ll need your link to open it again.',
      screen: '/more/settings', screenLabel: 'Open Settings'),
];
