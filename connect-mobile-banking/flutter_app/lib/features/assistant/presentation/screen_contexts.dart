import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/screen_context.dart';

// Where the customer is. Each screen publishes its context for its own location (tabs stay alive side by side, so
// a location says which one is showing); the router says which location is showing. The assistant asks this
// whenever it needs to know where the customer is. [app.js pageContext]
class ScreenContexts extends ChangeNotifier {
  final Map<String, ScreenContext> _byPath = {};
  String _path = '/home';
  ScreenContext _last = ScreenContext.home;

  String get path => _path;

  /// The context showing now. A screen with none of its own (the forms WebView) keeps the last one.
  ScreenContext get current => _byPath[_path] ?? _last;

  /// Whether the screen at [path] has published yet.
  bool has(String path) => _byPath.containsKey(path);

  void publish(String path, ScreenContext context) {
    if (_byPath[path] == context) return;
    _byPath[path] = context;
    if (path == _path) _last = context;
    notifyListeners(); // a screen may be waiting for this one (whenShowing)
  }

  void showing(String path) {
    if (path == _path) return;
    _path = path;
    final own = _byPath[path];
    if (own != null) _last = own;
    notifyListeners();
  }

  /// Waits (up to [timeout]) until the screen at [path] is showing and has published a context that [matches];
  /// then, or when the time is up, gives the context showing.
  Future<ScreenContext> whenShowing(String path,
      {bool Function(ScreenContext context)? matches, Duration timeout = const Duration(seconds: 6)}) {
    bool ready() {
      final own = _byPath[path];
      return _path == path && own != null && (matches == null || matches(own));
    }

    if (ready()) return Future.value(current);
    final done = Completer<ScreenContext>();
    late final Timer timer;
    void check() {
      if (done.isCompleted || !ready()) return;
      timer.cancel();
      removeListener(check);
      done.complete(current);
    }

    timer = Timer(timeout, () {
      removeListener(check);
      if (!done.isCompleted) done.complete(current);
    });
    addListener(check);
    return done.future;
  }

  void clear() {
    _byPath.clear();
    _last = ScreenContext.home;
  }
}

/// Publishes a screen's context for its location, after the frame (never during a build).
class PublishContext extends StatefulWidget {
  const PublishContext({super.key, required this.contexts, required this.path, required this.context, required this.child});

  final ScreenContexts contexts;
  final String path;
  final ScreenContext context;
  final Widget child;

  @override
  State<PublishContext> createState() => _PublishContextState();
}

class _PublishContextState extends State<PublishContext> {
  void _publish() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.contexts.publish(widget.path, widget.context);
      });

  @override
  void initState() {
    super.initState();
    _publish();
  }

  @override
  void didUpdateWidget(PublishContext old) {
    super.didUpdateWidget(old);
    if (old.context != widget.context || old.path != widget.path) _publish();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
