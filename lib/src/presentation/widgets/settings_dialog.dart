import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photographers_reference_app/src/services/biometric_auth_service.dart';
import 'package:photographers_reference_app/src/services/biometric_settings_service.dart';
import 'package:photographers_reference_app/src/services/storage_diagnostics_service.dart';
import 'package:photographers_reference_app/src/presentation/widgets/rating_prompt_handler.dart';

import 'package:photographers_reference_app/backup.service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.appVersion,
  });

  final String? appVersion;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final _authService = BiometricAuthService();
  final _settings = BiometricSettingsService.instance;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _cacheLoading = true;
  int _cacheSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
    _loadCacheSize();
  }

  Future<void> _loadBiometrics() async {
    await _settings.load();
    final available = await _authService.isAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = _settings.enabledNotifier.value;
      _loading = false;
    });
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometrics not available on this device')),
      );
      return;
    }
    final ok = await _authService.authenticate();
    if (!ok) {
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      return;
    }
    await _settings.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _loadCacheSize() async {
    final size = await StorageDiagnosticsService.getCacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _cacheSizeBytes = size;
      _cacheLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color.fromARGB(255, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Refma: version ${widget.appVersion ?? '-'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Iconsax.export_3,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Create a backup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Save locally all the data and database',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () {
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          BackupService.promptAndRun(rootContext);
                        });
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(
                        Iconsax.import_2,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Restore from backup',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Import a backup file and restore your data',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () {
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          BackupService.restoreFromBackup(rootContext);
                        });
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(
                        Iconsax.trash,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Clear cache',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _cacheLoading
                            ? 'Calculating cache size...'
                            : 'Current cache: ${StorageDiagnosticsService.formatBytes(_cacheSizeBytes)}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () async {
                        setState(() => _cacheLoading = true);
                        await StorageDiagnosticsService.clearCache();
                        await StorageDiagnosticsService.logStorage();
                        await _loadCacheSize();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache cleared'),
                          ),
                        );
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      SwitchListTile(
                        value: _biometricEnabled,
                        onChanged: _biometricAvailable ? _toggleBiometric : null,
                        activeColor: const Color.fromARGB(255, 35, 107, 166),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text(
                          'Biometric lock',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          _biometricAvailable
                              ? 'Require Face ID / Touch ID to unlock the app'
                              : 'Biometrics not available on this device',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.star_rate_rounded,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Rate the app',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Leave a quick rating in the App Store',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () {
                        final rootContext =
                            Navigator.of(context, rootNavigator: true).context;
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          RatingPromptHandler.showRatingDialog(rootContext);
                        });
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Have a question or feedback?',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SizedBox(
                          height: 44,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 35, 107, 166),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _openTelegram(context),
                            child: const Text(
                              'Message the author on Telegram',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTelegram(BuildContext context) async {
    final uri = Uri.parse('https://t.me/isdemx');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  }
}
