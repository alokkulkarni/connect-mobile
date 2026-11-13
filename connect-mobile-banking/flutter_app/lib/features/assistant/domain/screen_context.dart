// What the screen the customer is on tells the assistant (docs/CONTRACT.md section 3). Only page, view, stage,
// applicationId and paymentId go to the server; who the customer is never does. [talk.js pageFields]

class ScreenContext {
  const ScreenContext({
    required this.page,
    this.view = '',
    this.stage = '',
    this.applicationId = '',
    this.paymentId = '',
    required this.label,
    required this.launcher,
    this.draft = '',
  });

  final String page, view, stage, applicationId, paymentId; // sent to the server
  final String label; // "Money Hub", "Disputing Amazon £32.45": shown in the app only
  final String launcher; // the launcher's words
  final String draft; // words offered for the chat box, unsent

  static const home = ScreenContext(page: 'home', label: 'Home', launcher: 'Ask us anything');

  /// What decides whether the customer has moved somewhere new.   [app.js pageKey]
  String get key => [page, view, stage, applicationId, paymentId].join('|');

  Map<String, String> toFields() =>
      {'page': page, 'view': view, 'stage': stage, 'applicationId': applicationId, 'paymentId': paymentId};

  @override
  bool operator ==(Object other) =>
      other is ScreenContext && other.key == key && other.label == label && other.launcher == launcher && other.draft == draft;

  @override
  int get hashCode => Object.hash(key, label, launcher, draft);
}
