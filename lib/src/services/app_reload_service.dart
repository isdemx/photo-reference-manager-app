class AppReloadService {
  AppReloadService._();

  static final AppReloadService instance = AppReloadService._();

  Future<void> Function()? _reloadCallback;

  void register(Future<void> Function() callback) {
    _reloadCallback = callback;
  }

  void unregister(Future<void> Function() callback) {
    if (_reloadCallback == callback) {
      _reloadCallback = null;
    }
  }

  Future<void> reload() async {
    final callback = _reloadCallback;
    if (callback == null) return;
    await callback();
  }
}
