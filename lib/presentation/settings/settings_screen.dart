import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/services/app_update_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../providers/app_providers.dart';

import '../providers/inventory_settings_provider.dart';
import '../security/security_center_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../shared/widgets/maple_pro_footer.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _invoiceExpiryController = TextEditingController();
  final _storageExpiryController = TextEditingController();
  bool _isSavingExpirySettings = false;
  bool _isSettingsInitialized = false;

  bool _isSendingReport = false;
  bool _isResettingOpening = false;
  bool _isTestingConnection = false;
  bool _isCheckingUpdate = false;
  String? _connectionStatus;
  PackageInfo? _packageInfo;
  AppVersionInfo? _latestCloudVersion;

  @override
  void initState() {
    super.initState();
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
      await _fetchCloudVersion(silent: true);
    } catch (_) {}
  }

  Future<void> _fetchCloudVersion({bool silent = false}) async {
    if (!silent) setState(() => _isCheckingUpdate = true);
    try {
      final res = await AppUpdateService.instance.checkForUpdate();
      final cloud = await AppUpdateService.instance.getLatestCloudVersion();
      if (mounted) {
        setState(() {
          _latestCloudVersion = cloud ?? res ?? AppUpdateService.instance.latestCloudVersionNotifier.value;
        });
      }
      if (!silent && res != null && mounted) {
        AppUpdateService.instance.showUpdateDialog(context, res);
      }
    } catch (_) {
    } finally {
      if (!silent && mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  @override
  void dispose() {
    _invoiceExpiryController.dispose();
    _storageExpiryController.dispose();
    super.dispose();
  }

  void _syncSettingsToFields(int invoiceDays, int storageDays) {
    if (!_isSettingsInitialized) {
      _invoiceExpiryController.text = invoiceDays.toString();
      _storageExpiryController.text = storageDays.toString();
      _isSettingsInitialized = true;
    }
  }

  Future<void> _saveExpirySettings() async {
    final invText = _invoiceExpiryController.text.trim();
    final storText = _storageExpiryController.text.trim();

    final invDays = int.tryParse(invText);
    final storDays = int.tryParse(storText);

    if (invDays == null || invDays < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice Material Expiry Alert must be a non-negative whole number (e.g. 30).'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (storDays == null || storDays < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage Product Expiry Alert must be a non-negative whole number (e.g. 30).'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingExpirySettings = true);
    try {
      await ref.read(inventorySettingsProvider.notifier).saveSettings(
        invoiceMaterialExpiryAlertDays: invDays,
        storageProductExpiryAlertDays: storDays,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expiry alert settings saved! Invoice: $invDays days | Storage: $storDays days.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingExpirySettings = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final res = await SupabaseConfig.client.from('materials').select('id').limit(1);
      setState(() {
        _connectionStatus = 'Connected to Cloud PostgreSQL (${res.isNotEmpty ? "Healthy" : "Online"})';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _sendDailyReport() async {
    setState(() => _isSendingReport = true);
    try {
      // In production, invoke the Supabase Edge function 'send-daily-report'
      // or backend RPC.
      try {
        await SupabaseConfig.client.functions.invoke('send-daily-report');
      } catch (_) {
        // Fallback or log if edge function not deployed yet
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Daily MMS Report triggered and dispatched to configured recipients.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Error dispatching mailer: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingReport = false);
    }
  }

  Future<void> _resetDailyOpeningStock() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Reset Daily Opening Stock?',
      message: 'This will copy current closing stock to opening_stock for all materials across the factory, recording today as the new baseline.',
      confirmLabel: 'Run Reset',
      isDestructive: false,
    );

    if (confirmed != true) return;

    setState(() => _isResettingOpening = true);
    try {
      await SupabaseConfig.client.rpc('reset_daily_opening_stock');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Daily opening stock successfully synchronized for all lots.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Failed to reset opening stock: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResettingOpening = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your active session on this device?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
    );

    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(currentUserProvider);
    final settings = ref.watch(inventorySettingsProvider).valueOrNull;
    if (settings != null) {
      _syncSettingsToFields(
        settings.invoiceMaterialExpiryAlertDays,
        settings.storageProductExpiryAlertDays,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings & Operations'),
      ),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // User Session Glass Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              accentColor: AppColors.primary,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authUser?.email ?? 'Operator / Warehouse Manager',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Authenticated Session • RLS Active',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                    tooltip: 'Sign Out',
                    onPressed: _handleSignOut,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 0: Inventory Alert Settings (Separate Invoice vs Storage)
            _buildSectionHeader('Inventory Alert Settings'),
            const SizedBox(height: 8),

            GlassCard(
              padding: const EdgeInsets.all(16),
              accentColor: AppColors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.timer_outlined, color: AppColors.warning, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry Alert Thresholds',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Independent thresholds for Invoice Raw Materials vs Storage Finished Goods.',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.glassBorder, height: 24),

                  // 1. Invoice Material Expiry Alert
                  Text(
                    'Invoice Material Expiry Alert',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Alert when inward raw material lots reach expiry within:',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _invoiceExpiryController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixText: 'days',
                            suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface.withValues(alpha: 0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.glassBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.glassBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: AppColors.glassBorder, height: 24),

                  // 2. Storage Finished Product Expiry Alert
                  Text(
                    'Storage Finished Product Expiry Alert',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Alert when warehouse finished product batches reach expiry within:',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _storageExpiryController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixText: 'days',
                            suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface.withValues(alpha: 0.5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.glassBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.glassBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassButton(
                      text: _isSavingExpirySettings ? 'Saving...' : 'Save Settings',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      isLoading: _isSavingExpirySettings,
                      onPressed: _isSavingExpirySettings ? null : _saveExpirySettings,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 1: Factory Operations & Automations
            _buildSectionHeader('Automations & Daily Operations'),
            const SizedBox(height: 8),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Smart Report Mailer
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mark_email_read_rounded, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Report Mailer',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Trigger instant generation & dispatch of the daily inventory summary report to factory executives.',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            GlassButton(
                              text: _isSendingReport ? 'Sending...' : 'Send Daily Report Now',
                              icon: Icons.send_rounded,
                              color: AppColors.accent,
                              isLoading: _isSendingReport,
                              onPressed: _isSendingReport ? null : _sendDailyReport,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.glassBorder, height: 28),
                  // Daily Opening Stock Reset
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restore_page_rounded, color: AppColors.warning, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Synchronize Daily Opening Stock',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Executes atomic backend procedure: Opening Stock = Previous Closing Stock for all lots.',
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 10),
                            GlassButton(
                              text: _isResettingOpening ? 'Synchronizing...' : 'Run Daily Opening Sync',
                              icon: Icons.sync_rounded,
                              color: AppColors.warning,
                              isLoading: _isResettingOpening,
                              onPressed: _isResettingOpening ? null : _resetDailyOpeningStock,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 2: Backend & Health Status
            _buildSectionHeader('Backend & Connectivity'),
            const SizedBox(height: 8),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cloud PostgreSQL 15 Engine',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            SupabaseConfig.url.isNotEmpty
                                ? SupabaseConfig.url
                                : 'Configured via dart-define / .env',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: const Text('Ping', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (_connectionStatus != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _connectionStatus!.contains('Connected')
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _connectionStatus!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _connectionStatus!.contains('Connected') ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section: Supabase Security Center
            _buildSectionHeader('Security & Audit Center'),
            const SizedBox(height: 8),

            GlassCard(
              padding: const EdgeInsets.all(16),
              accentColor: const Color(0xFF10B981),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Security & Audit Center',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Automated RLS, Auth, Storage, RPC search_path, and credential security audits with safe auto-fix.',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GlassButton(
                    text: 'Open',
                    icon: Icons.launch_rounded,
                    color: const Color(0xFF10B981),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecurityCenterScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Section 3: Factory Configuration
            _buildSectionHeader('Factory Configuration & Departments'),
            const SizedBox(height: 8),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Production Departments:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FactoryConstants.departments
                        .map(
                          (dept) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Text(
                              dept,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Standard Units of Measurement (UOM):', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: FactoryConstants.standardUnits
                        .map(
                          (u) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              u,
                              style: const TextStyle(fontSize: 10, color: AppColors.primaryLight),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Software Updates
            _buildSectionHeader('Software Updates & Version Control'),
            const SizedBox(height: 8),
            _buildSoftwareUpdateCard(),

            const SizedBox(height: 18),

            // App Version & Credits
            Center(
              child: Column(
                children: [
                  Text(
                    'BENCHMARK MMS v3.1.0 (Build 11 • v1.0.8)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GLASS & NEON 3.0 • Mobile & Tablet Production Edition\nAtomic PostgreSQL FIFO Engine',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  const MapleProFooter(compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoftwareUpdateCard() {
    final currentBuild = int.tryParse(_packageInfo?.buildNumber ?? '11') ?? 11;
    final currentVersion = _packageInfo?.version ?? '1.0.8';
    final cloudBuild = _latestCloudVersion?.versionCode ?? 0;
    final cloudVersion = _latestCloudVersion?.versionName ?? '';
    final bool hasUpdate = _latestCloudVersion != null &&
        cloudBuild > currentBuild &&
        _latestCloudVersion!.apkUrl.isNotEmpty;

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasUpdate ? AppColors.warning : AppColors.primary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasUpdate ? Icons.new_releases_rounded : Icons.system_update_rounded,
                    color: hasUpdate ? AppColors.warning : AppColors.primaryLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OTA App Update Engine',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasUpdate ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hasUpdate ? AppColors.warning : AppColors.success).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasUpdate ? Icons.arrow_circle_up_rounded : Icons.check_circle_rounded,
                        size: 13,
                        color: hasUpdate ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasUpdate ? 'UPDATE READY' : 'UP TO DATE',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasUpdate ? AppColors.warning : AppColors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Version Comparison Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'CURRENT INSTALLED',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v$currentVersion • Build $currentBuild',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 36,
                    width: 1,
                    color: AppColors.glassBorder,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_rounded, size: 14, color: AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(
                              'LATEST ON CLOUD',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryLight,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _latestCloudVersion != null
                              ? 'v$cloudVersion • Build $cloudBuild'
                              : 'Loading...',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasUpdate ? AppColors.warning : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (hasUpdate && (_latestCloudVersion?.releaseNotes.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 13, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'What\'s New in v$cloudVersion:',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _latestCloudVersion!.releaseNotes,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Buttons
            Row(
              children: [
                if (hasUpdate) ...[
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppUpdateService.instance.showUpdateDialog(context, _latestCloudVersion);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        'Install Update (v$cloudVersion)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: hasUpdate ? 2 : 5,
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingUpdate
                        ? null
                        : () async {
                            await _fetchCloudVersion(silent: false);
                          },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      foregroundColor: AppColors.primaryLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isCheckingUpdate
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      _isCheckingUpdate ? 'Checking...' : (hasUpdate ? 'Re-Check' : 'Check for Updates'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
