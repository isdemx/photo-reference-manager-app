import 'package:flutter/material.dart';

class _RouteSnapshot {
  final String name;
  final Object? arguments;

  const _RouteSnapshot({
    required this.name,
    this.arguments,
  });

  bool sameAs(_RouteSnapshot? other) {
    if (other == null) return false;
    return name == other.name && identical(arguments, other.arguments);
  }
}

class NavigationHistoryService {
  NavigationHistoryService._();

  static final NavigationHistoryService instance = NavigationHistoryService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final NavigatorObserver observer = _NavigationHistoryObserver();

  final List<_RouteSnapshot> _back = <_RouteSnapshot>[];
  final List<_RouteSnapshot> _forward = <_RouteSnapshot>[];

  _RouteSnapshot? _current;
  _HistoryAction _pendingAction = _HistoryAction.none;

  bool canGoForward() => _forward.isNotEmpty;

  bool canGoBack(BuildContext context) => Navigator.of(context).canPop();

  void goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;

    if (_current != null) {
      _forward.add(_current!);
      _current = _back.isNotEmpty ? _back.removeLast() : null;
      _notify();
    }

    _pendingAction = _HistoryAction.back;
    navigator.maybePop();
  }

  void goForward(BuildContext context) {
    if (_forward.isEmpty) return;

    final target = _forward.removeLast();
    if (_current != null) {
      _back.add(_current!);
    }
    _current = target;
    _notify();

    _pendingAction = _HistoryAction.forward;
    Navigator.of(context).pushNamed(target.name, arguments: target.arguments);
  }

  void onDidPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pendingAction == _HistoryAction.forward) {
      _pendingAction = _HistoryAction.none;
      return;
    }

    final pushed = _snapshotOf(route);
    if (pushed == null) return;

    if (_current != null && !_current!.sameAs(pushed)) {
      _back.add(_current!);
    }
    _current = pushed;
    _forward.clear();
    _notify();
  }

  void onDidPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_pendingAction == _HistoryAction.back) {
      _pendingAction = _HistoryAction.none;
      return;
    }

    final popped = _snapshotOf(route);
    if (popped == null) return;

    _forward.add(_current?.sameAs(popped) == true ? _current! : popped);

    final previous = _snapshotOf(previousRoute);
    _current = previous;

    if (previous != null && _back.isNotEmpty && _back.last.sameAs(previous)) {
      _back.removeLast();
    }

    _notify();
  }

  void onDidReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    final oldSnapshot = _snapshotOf(oldRoute);
    final newSnapshot = _snapshotOf(newRoute);

    if (oldSnapshot != null && _current?.sameAs(oldSnapshot) == true) {
      _current = newSnapshot;
      _notify();
      return;
    }

    for (var i = 0; i < _back.length; i++) {
      if (_back[i].sameAs(oldSnapshot)) {
        if (newSnapshot == null) {
          _back.removeAt(i);
        } else {
          _back[i] = newSnapshot;
        }
        _notify();
        return;
      }
    }
  }

  _RouteSnapshot? _snapshotOf(Route<dynamic>? route) {
    if (route == null) return null;
    if (route is! PageRoute<dynamic>) return null;

    final settings = route.settings;
    final name = settings.name;
    if (name == null || name.isEmpty) return null;

    return _RouteSnapshot(name: name, arguments: settings.arguments);
  }

  void _notify() {
    revision.value++;
  }
}

enum _HistoryAction {
  none,
  back,
  forward,
}

class _NavigationHistoryObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    NavigationHistoryService.instance.onDidPush(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    NavigationHistoryService.instance.onDidPop(route, previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    NavigationHistoryService.instance
        .onDidReplace(newRoute: newRoute, oldRoute: oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
