import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../providers/inventory_settings_provider.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _invoiceDaysController;
  late TextEditingController _storageDaysController;
  bool _isSaving = false;
  PackageInfo? _packageInfo;
  AppVersionInfo? _latestCloudVersion;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(inventorySettingsProvider).valueOrNull;
    _invoiceDaysController = TextEditingController(
      text: (current?.invoiceMaterialExpiryAlertDays ?? 30).toString(),
    );
    _storageDaysController = TextEditingController(
      text: (current?.storageProductExpiryAlertDays ?? 30).toString(),
    );
    _initAppVersionInfo();
  }

  Future<void> _initAppVersionInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
          _latestCloudVersion = AppUpdateService.instance.latestCloudVersionNotifier.value ??
              AppUpdateService.instance.updateAvailableNotifier.value;
        });
      }
      await _checkUpdate(silent: true);
    } catch (_) {}
  }

  Future<void> _checkUpdate({bool silent = false}) async {
    if (!silent) setState(() => _isCheckingUpdate = true);
    try {
      final res = await AppUpdateService.instance.checkForUpdate();
      final cloud = await AppUpdateService.instance.getLatestCloudVersion();
      if (mounted) {
        setState(() {
          _latestCloudVersion = cloud ?? res ?? AppUpdateService.instance.latestCloudVersionNotifier.value;
        });
      }
      if (!silent && mounted) {
        if (res != null) {
          AppUpdateService.instance.showUpdateDialog(context, res);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Benchmark MMS is completely up to date!'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking update: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  void dispose() {
    _invoiceDaysController.dispose();
    _storageDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final invDays = int.parse(_invoiceDaysController.text.trim());
      final storDays = int.parse(_storageDaysController.text.trim());

      await ref.read(inventorySettingsProvider.notifier).saveSettings(
            invoiceMaterialExpiryAlertDays: invDays,
            storageProductExpiryAlertDays: storDays,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Executive threshold settings saved successfully.'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Management Settings & Configurations',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Independent Expiry Alert Thresholds
                _buildSectionTitle('EXPIRY ALERT THRESHOLDS', const Color(0xFFF59E0B)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Independent Expiry Days Configuration',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set independent lead times in days for raw material invoices and finished storage products.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 20),

                      // Invoice Material Alert Days
                      TextFormField(
                        controller: _invoiceDaysController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Invoice Material Expiry Alert Days',
                          labelStyle: const TextStyle(color: AppColors.primaryLight),
                          hintText: 'e.g. 30',
                          helperText: 'Triggers alerts when material lot approaches expiry within X days.',
                          helperStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          prefixIcon: const Icon(Icons.timer_outlined, size: 20, color: AppColors.primaryLight),
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter days';
                          final d = int.tryParse(val.trim());
                          if (d == null || d <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Storage Product Alert Days
                      TextFormField(
                        controller: _storageDaysController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Storage Product Expiry Alert Days',
                          labelStyle: const TextStyle(color: Color(0xFFF59E0B)),
                          hintText: 'e.g. 30',
                          helperText: 'Triggers alerts when storage finished batch approaches expiry within X days.',
                          helperStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          prefixIcon: const Icon(Icons.layers_outlined, size: 20, color: Color(0xFFF59E0B)),
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter days';
                          final d = int.tryParse(val.trim());
                          if (d == null || d <= 0) return 'Must be a positive integer';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          final button = ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save Thresholds',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );

                          if (isNarrow) {
                            return SizedBox(
                              width: double.infinity,
                              child: button,
                            );
                          }
                          return Align(
                            alignment: Alignment.centerRight,
                            child: button,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section 2: Report & Export Preferences
                _buildSectionTitle('REPORT & EXPORT PREFERENCES', const Color(0xFF6366F1)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    children: [
                      _buildPreferenceTile(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'PDF Page Orientation',
                        subtitle: 'A4 Portrait for Master lists, A4 Landscape for transaction ledgers',
                        trailing: 'Automatic',
                      ),
                      const Divider(color: Color(0xFF1F2937)),
                      _buildPreferenceTile(
                        icon: Icons.date_range_rounded,
                        title: 'Default Dashboard Date Filter',
                        subtitle: 'Primary interval applied on initial portal loading',
                        trailing: 'All Time / Live',
                      ),
                      const Divider(color: Color(0xFF1F2937)),
                      _buildPreferenceTile(
                        icon: Icons.security_rounded,
                        title: 'Server-Side Access Guard',
                        subtitle: 'Strict PostgreSQL RLS and role claim verification',
                        trailing: 'Enforced',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Section 3: APPLICATION UPDATES (OTA)
                _buildSectionTitle('APPLICATION UPDATES (OTA)', const Color(0xFF10B981)),
                const SizedBox(height: 12),
                _buildAppUpdateCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 280;
          final iconBox = Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
          );
          final textCol = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          );
          final trailingBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Text(
              trailing,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD1D5DB)),
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconBox,
                    const SizedBox(width: 10),
                    Expanded(child: textCol),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: trailingBadge,
                ),
              ],
            );
          }

          return Row(
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(child: textCol),
              const SizedBox(width: 8),
              trailingBadge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppUpdateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.system_update_rounded, color: AppColors.primaryLight, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Over-the-Air Update Engine',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ValueListenableBuilder<String>(
                      valueListenable: AppUpdateService.instance.statusNotifier,
                      builder: (context, status, _) => Text(
                        status,
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<AppVersionInfo?>(
                valueListenable: AppUpdateService.instance.updateAvailableNotifier,
                builder: (context, update, _) {
                  final hasUpdate = update != null;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (hasUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (hasUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasUpdate ? Icons.arrow_circle_up_rounded : Icons.check_circle_rounded,
                          size: 13,
                          color: hasUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasUpdate ? 'UPDATE READY' : 'UP TO DATE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Current and Cloud Version Display
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 280;
              final installedCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Installed Version', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    _packageInfo != null
                        ? 'v${_packageInfo!.version}+${_packageInfo!.buildNumber}'
                        : 'v1.0.0+33',
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              );
              final latestCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Latest Cloud Version', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    _latestCloudVersion != null
                        ? 'v${_latestCloudVersion!.versionName}+${_latestCloudVersion!.versionCode}'
                        : (_packageInfo != null ? 'v${_packageInfo!.version}+${_packageInfo!.buildNumber}' : 'v1.0.0+33'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _latestCloudVersion != null &&
                              int.tryParse(_packageInfo?.buildNumber ?? '0') != null &&
                              _latestCloudVersion!.versionCode > int.parse(_packageInfo!.buildNumber)
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              );

              if (isVeryNarrow) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      installedCol,
                      const Divider(color: Color(0xFF374151), height: 16),
                      latestCol,
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(child: installedCol),
                    Container(width: 1, height: 30, color: const Color(0xFF374151)),
                    const SizedBox(width: 12),
                    Expanded(child: latestCol),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Check for Updates / Install Update Button
          ValueListenableBuilder<AppVersionInfo?>(
            valueListenable: AppUpdateService.instance.updateAvailableNotifier,
            builder: (context, update, _) {
              final hasUpdate = update != null;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 450;
                  final checkBtn = OutlinedButton.icon(
                    onPressed: _isCheckingUpdate ? null : () => _checkUpdate(silent: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF374151)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isCheckingUpdate
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_isCheckingUpdate ? 'Checking Cloud...' : 'Check for Updates'),
                  );

                  if (hasUpdate) {
                    final updateBtn = ElevatedButton.icon(
                      onPressed: () => AppUpdateService.instance.showUpdateDialog(context, update),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Install Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          updateBtn,
                          const SizedBox(height: 10),
                          checkBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: updateBtn),
                        const SizedBox(width: 10),
                        Expanded(child: checkBtn),
                      ],
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    child: checkBtn,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
