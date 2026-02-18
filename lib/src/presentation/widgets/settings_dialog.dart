import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photographers_reference_app/src/services/biometric_auth_service.dart';
import 'package:photographers_reference_app/src/services/biometric_settings_service.dart';
import 'package:photographers_reference_app/src/services/storage_diagnostics_service.dart';
import 'package:photographers_reference_app/src/presentation/widgets/rating_prompt_handler.dart';
import 'package:photographers_reference_app/src/presentation/bloc/theme_cubit.dart';
import 'package:photographers_reference_app/src/services/theme_settings_service.dart';
import 'package:photographers_reference_app/src/presentation/theme/app_theme.dart';

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
        const SnackBar(
            content: Text('Biometrics not available on this device')),
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
    final theme = Theme.of(context);
    final colors = context.appThemeColors;
    final bool isDark = theme.brightness == Brightness.dark;
    final textPrimary = colors.text;
    final textSecondary = colors.subtle;
    final dividerColor = colors.border;
    final tileBg = colors.surface;
    final titleState = context.watch<ThemeCubit>().state;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16),
          color: tileBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close, color: textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Refma: version ${widget.appVersion ?? '-'}',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Divider(color: dividerColor, height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 2),
                    ListTile(
                      leading: Icon(
                        Iconsax.sun_1,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Theme',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Dark by default. Switch to Light or Auto',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dividerColor),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              titleState.preference == AppThemePreference.dark,
                              titleState.preference == AppThemePreference.light,
                              titleState.preference ==
                                  AppThemePreference.system,
                            ],
                            onPressed: (index) {
                              final pref = switch (index) {
                                0 => AppThemePreference.dark,
                                1 => AppThemePreference.light,
                                _ => AppThemePreference.system,
                              };
                              context.read<ThemeCubit>().setPreference(pref);
                            },
                            borderRadius: BorderRadius.circular(12),
                            borderColor: Colors.transparent,
                            selectedBorderColor: Colors.transparent,
                            fillColor: isDark
                                ? colors.surfaceAlt
                                : theme.colorScheme.surfaceContainerHigh,
                            color: textSecondary,
                            selectedColor: textPrimary,
                            constraints: const BoxConstraints(
                              minHeight: 30,
                              minWidth: 72,
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Dark'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Light'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('Auto'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Divider(color: dividerColor, height: 1),
                    ListTile(
                      leading: Icon(
                        Iconsax.export_3,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Create a backup',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Save locally all the data and database',
                        style: TextStyle(
                          color: textSecondary,
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
                    Divider(color: dividerColor, height: 1),
                    ListTile(
                      leading: Icon(
                        Iconsax.import_2,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Restore from backup',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Import a backup file and restore your data',
                        style: TextStyle(
                          color: textSecondary,
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
                    Divider(color: dividerColor, height: 1),
                    ListTile(
                      leading: Icon(
                        Iconsax.trash,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Clear cache',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        _cacheLoading
                            ? 'Calculating cache size...'
                            : 'Current cache: ${StorageDiagnosticsService.formatBytes(_cacheSizeBytes)}',
                        style: TextStyle(
                          color: textSecondary,
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
                    Divider(color: dividerColor, height: 1),
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
                        onChanged:
                            _biometricAvailable ? _toggleBiometric : null,
                        activeColor: const Color.fromARGB(255, 35, 107, 166),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        title: Text(
                          'Biometric lock',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          _biometricAvailable
                              ? 'Require Face ID / Touch ID to unlock the app'
                              : 'Biometrics not available on this device',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.star_rate_rounded,
                        color: textSecondary,
                      ),
                      title: Text(
                        'Rate the app',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Leave a quick rating in the App Store',
                        style: TextStyle(
                          color: textSecondary,
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
                    Divider(color: dividerColor, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Have a question or feedback?',
                      style: TextStyle(color: textSecondary, fontSize: 13),
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
                              backgroundColor: colors.accent,
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
