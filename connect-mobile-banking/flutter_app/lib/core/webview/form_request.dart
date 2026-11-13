// A shared form to show in the forms WebView (docs/CONTRACT.md section 9): the exact page, the origins it may load,
// and, after it loads, one event for the page (the bridge's app → page direction).
class FormRequest {
  const FormRequest({required this.url, required this.title, required this.allowedOrigins, this.afterLoad = '', this.mortgage = false});

  final Uri url;
  final String title;

  /// The bank's own origins: the app's, and the dispute pages'. Anything else opens in the system browser.
  final Set<String> allowedOrigins;

  /// JavaScript to run once the page has loaded (only the bridge's own events), or ''.
  final String afterLoad;

  /// The mortgage application: its "Call us" may ask the app to start a call joined to it.
  final bool mortgage;
}

/// "https://host[:port]" for a URL, as the WebView compares origins.
String originOf(Uri url) => Uri(scheme: url.scheme, host: url.host, port: url.hasPort ? url.port : null).toString();
