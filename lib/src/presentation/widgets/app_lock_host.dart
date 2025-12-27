import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:photographers_reference_app/src/services/biometric_auth_service.dart';
import 'package:photographers_reference_app/src/services/biometric_settings_service.dart';

class AppLockHost extends StatefulWidget {
  const AppLockHost({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockHost> createState() => _AppLockHostState();
}

class _AppLockHostState extends State<AppLockHost>
    with WidgetsBindingObserver {
  final _authService = BiometricAuthService();
  final _settings = BiometricSettingsService.instance;
  VoidCallback? _enabledListener;

  bool _locked = false;
  bool _authInProgress = false;
  bool _available = false;
  bool _hasUnlockedThisSession = false;
  bool _wentToBackground = false;
  bool _ready = false;
  bool _backgroundObscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _locked = true;
    if (mounted) setState(() {});
    await _settings.load();
    _available = await _authService.isAvailable();
    _enabledListener = _onEnabledChanged;
    _settings.enabledNotifier.addListener(_enabledListener!);
    _ready = true;
    _syncLockState();
  }

  void _onEnabledChanged() {
    _hasUnlockedThisSession = false;
    _syncLockState();
  }

  void _syncLockState() {
    final enabled = _settings.enabledNotifier.value;
    if (!_available && enabled) {
      _settings.setEnabled(false);
      return;
    }
    if (!_ready) {
      _locked = true;
      if (mounted) setState(() {});
      return;
    }
    if (enabled) {
      if (!_hasUnlockedThisSession) {
        _locked = true;
        if (mounted) setState(() {});
        _authenticate();
      } else {
        _locked = false;
        if (mounted) setState(() {});
      }
    } else {
      _locked = false;
      _hasUnlockedThisSession = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _authenticate() async {
    if (_authInProgress) return;
    _authInProgress = true;
    bool ok = false;
    try {
      ok = await _authService.authenticate();
    } catch (_) {
      ok = false;
    } finally {
      _authInProgress = false;
    }
    if (!mounted) return;
    setState(() {
      _locked = !ok;
      if (ok) {
        _hasUnlockedThisSession = true;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authInProgress) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _wentToBackground = true;
      _backgroundObscured = true;
      if (_settings.enabledNotifier.value) {
        _locked = true;
        if (mounted) setState(() {});
      }
    }
    if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      _backgroundObscured = false;
      if (_settings.enabledNotifier.value) {
        _locked = true;
        if (mounted) setState(() {});
      }
      _refreshAvailability();
      _hasUnlockedThisSession = false;
      _syncLockState();
    }
  }

  Future<void> _refreshAvailability() async {
    _available = await _authService.isAvailable();
    if (!_available && _settings.enabledNotifier.value) {
      await _settings.setEnabled(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_enabledListener != null) {
      _settings.enabledNotifier.removeListener(_enabledListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                    ),
                  ),
                ),
                if (!_backgroundObscured)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'App Locked',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Unlock with Face ID / Touch ID',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _authenticate,
                          child: const Text('Unlock'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
