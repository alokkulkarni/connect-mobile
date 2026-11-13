// Small rules of the web widget (connect-banking-app/web/widget/talk.js), as pure functions.

/// What a finished chat says.
const chatEndedEvent = 'application/vnd.amazonaws.connect.event.chat.ended';

/// Back from an assistant, the app tells ARIA with one of these notes. It is ours, never shown.   [talk.js RETURN_NOTES]
const returnNotePrefixes = ['Back from card dispute:', 'Back from mortgage application:'];

bool isReturnNote(String words) => returnNotePrefixes.any((label) => words.trim().startsWith(label));

/// Markdown emphasis shown as plain text: every message is written as text.   [talk.js plain]
String plain(String words) => words.replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2]!);

/// The dispute form's link in an assistant message: the dispute pages' address followed by `#k=<secret>`, or null.
/// [talk.js disputeToken]
String? disputeLinkIn(String words, String disputePagesUrl) {
  if (disputePagesUrl.isEmpty) return null;
  final at = words.indexOf(disputePagesUrl);
  if (at < 0) return null;
  final match = RegExp(r'^[^\s#]*#k=[A-Za-z0-9_-]{16,128}').firstMatch(words.substring(at));
  return match?.group(0);
}

/// Parts of a message, with the £ amounts marked so they can be shown in bold.   [format.js amounts]
List<({String text, bool amount})> amountParts(String text) {
  final parts = <({String text, bool amount})>[];
  var last = 0;
  for (final m in RegExp(r'[−-]?£\d[\d,]*(?:\.\d{1,2})?').allMatches(text)) {
    if (m.start > last) parts.add((text: text.substring(last, m.start), amount: false));
    parts.add((text: m.group(0)!, amount: true));
    last = m.end;
  }
  if (last < text.length) parts.add((text: text.substring(last), amount: false));
  return parts;
}
