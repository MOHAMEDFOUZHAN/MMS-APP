import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../main.dart';
import '../config/supabase_config.dart';
import '../constants/app_colors.dart';

class AppVersionInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String releaseNotes;
  final bool isMandatory;

  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  factory AppVersionInfo.fromMap(Map<String, dynamic> map) {
    return AppVersionInfo(
      versionCode: (map['version_code'] as num?)?.toInt() ?? 0,
      versionName: (map['version_name'] as String?) ?? '',
      apkUrl: (map['apk_url'] as String?) ?? '',
      releaseNotes: (map['release_notes'] as String?) ?? '',
      isMandatory: (map['is_mandatory'] as bool?) ?? false,
    );
  }
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _hasCheckedThisSession = false;
  final ValueNotifier<AppVersionInfo?> updateAvailableNotifier = ValueNotifier<AppVersionInfo?>(null);
  final ValueNotifier<AppVersionInfo?> latestCloudVersionNotifier = ValueNotifier<AppVersionInfo?>(null);
  final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Idle');

  /// Fetches the latest published release record from Supabase regardless of whether it is newer
  Future<AppVersionInfo?> getLatestCloudVersion() async {
    try {
      if (!SupabaseConfig.isInitialized) return null;
      final response = await SupabaseConfig.client
          .from('app_versions')
          .select()
          .eq('platform', 'android')
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response == null) return null;
      final info = AppVersionInfo.fromMap(response);
      latestCloudVersionNotifier.value = info;
      return info;
    } catch (e) {
      debugPrint('>>> [AppUpdateService] Error in getLatestCloudVersion: $e');
      return null;
    }
  }

  /// Check if a newer version is available on Supabase
  Future<AppVersionInfo?> checkForUpdate() async {
    debugPrint('>>> [AppUpdateService] checkForUpdate called. kIsWeb=$kIsWeb, isAndroid=${!kIsWeb && Platform.isAndroid}');
    if (kIsWeb || !Platform.isAndroid) {
      statusNotifier.value = 'OTA updates only supported on Android';
      return null;
    }

    try {
      statusNotifier.value = 'Connecting to Supabase...';
      debugPrint('>>> [AppUpdateService] Checking SupabaseConfig.isInitialized: ${SupabaseConfig.isInitialized}');
      if (!SupabaseConfig.isInitialized) {
        statusNotifier.value = 'Supabase not initialized';
        return null;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      debugPrint('>>> [AppUpdateService] Current build number: $currentBuildNumber (version: "${packageInfo.version}")');

      statusNotifier.value = 'Checking version registry (current build $currentBuildNumber)...';

      final response = await SupabaseConfig.client
          .from('app_versions')
          .select()
          .eq('platform', 'android')
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('>>> [AppUpdateService] Supabase response: $response');

      if (response == null) {
        statusNotifier.value = 'No version found in database';
        return null;
      }

      final remoteInfo = AppVersionInfo.fromMap(response);
      latestCloudVersionNotifier.value = remoteInfo;
      debugPrint('>>> [AppUpdateService] Remote: code=${remoteInfo.versionCode}, name=${remoteInfo.versionName}, url=${remoteInfo.apkUrl}');

      if (remoteInfo.versionCode > currentBuildNumber && remoteInfo.apkUrl.isNotEmpty) {
        debugPrint('>>> [AppUpdateService] UPDATE DETECTED! Returning remoteInfo');
        statusNotifier.value = 'New update available: v${remoteInfo.versionName} (Build ${remoteInfo.versionCode})';
        updateAvailableNotifier.value = remoteInfo;
        return remoteInfo;
      } else {
        debugPrint('>>> [AppUpdateService] Up to date (remote ${remoteInfo.versionCode} <= current $currentBuildNumber)');
        statusNotifier.value = 'Application is up to date (Build $currentBuildNumber)';
      }

      return null;
    } catch (e, stack) {
      debugPrint('>>> [AppUpdateService] EXCEPTION in checkForUpdate: $e\n$stack');
      statusNotifier.value = 'Error checking update: $e';
      return null;
    }
  }

  /// Automatically check and show prompt once per app session
  Future<void> checkAndPromptUpdate({BuildContext? context, bool forceManual = false}) async {
    debugPrint('>>> [AppUpdateService] checkAndPromptUpdate: forceManual=$forceManual, _hasCheckedThisSession=$_hasCheckedThisSession');
    if (!forceManual && _hasCheckedThisSession) {
      debugPrint('>>> [AppUpdateService] Already checked this session, skipping.');
      return;
    }

    final updateInfo = await checkForUpdate();
    final effectiveContext = (context != null && context.mounted) ? context : BenchmarkMmsApp.navigatorKey.currentContext;

    if (updateInfo != null) {
      _hasCheckedThisSession = true;
      if (effectiveContext != null && effectiveContext.mounted) {
        debugPrint('>>> [AppUpdateService] Showing update dialog on effectiveContext!');
        showUpdateDialog(effectiveContext, updateInfo);
      } else {
        debugPrint('>>> [AppUpdateService] Warning: Navigator context not available yet, dialog queued');
      }
    } else if (forceManual && effectiveContext != null && effectiveContext.mounted) {
      ScaffoldMessenger.of(effectiveContext).showSnackBar(
        SnackBar(
          content: Text(statusNotifier.value),
          backgroundColor: AppColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Display the update popup dialog with live progress bar
  void showUpdateDialog([BuildContext? context, AppVersionInfo? info]) {
    final updateInfo = info ?? updateAvailableNotifier.value;
    if (updateInfo == null) return;

    final targetContext = (context != null && context.mounted) ? context : BenchmarkMmsApp.navigatorKey.currentContext;
    if (targetContext == null) {
      debugPrint('>>> [AppUpdateService] Cannot show dialog, targetContext is null');
      return;
    }

    showDialog(
      context: targetContext,
      useRootNavigator: true,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) => _UpdateDialogContent(info: updateInfo),
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  final AppVersionInfo info;
  const _UpdateDialogContent({required this.info});

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  bool _isDownloading = false;
  int _progress = 0;
  String _statusMessage = '';
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0;
      _statusMessage = 'Connecting to update server...';
    });

    try {
      _otaSubscription = OtaUpdate()
          .execute(
            widget.info.apkUrl,
            destinationFilename: 'mms_update_${widget.info.versionCode}.apk',
          )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          debugPrint('>>> [OtaUpdate] Status: ${event.status}, Value: ${event.value}');

          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final parsed = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _progress = parsed;
                _statusMessage = 'Downloading update... $parsed%';
              });
              break;

            case OtaStatus.INSTALLING:
              setState(() {
                _progress = 100;
                _statusMessage = 'Opening Android installer... Please tap "Update"';
              });
              break;

            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'An update is already running in background.';
              });
              break;

            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Install permission denied. Please allow "Install unknown apps" in Android settings.';
              });
              break;

            case OtaStatus.DOWNLOAD_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Download failed. Please check internet connection and try again.';
              });
              break;

            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            default:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Update error occurred. Please try again.';
              });
              break;
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Update error: $err';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Unable to launch update: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: const Color(0xFF1E232E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primaryLight,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Software Update Available',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${widget.info.versionName} (Build ${widget.info.versionCode})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release notes box
            if (widget.info.releaseNotes.isNotEmpty) ...[
              Text(
                'WHAT\'S NEW',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  widget.info.releaseNotes,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Progress or Error status
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100.0 : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (!_isDownloading)
              Row(
                children: [
                  if (!widget.info.isMandatory)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                  if (!widget.info.isMandatory) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(_errorMessage != null ? 'Retry Update' : 'Update Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
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
}
