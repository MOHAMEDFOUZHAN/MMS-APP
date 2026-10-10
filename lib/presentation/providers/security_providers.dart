import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/security_auditor_service.dart';
import '../../core/security/security_finding_model.dart';
import '../../core/security/security_fix_service.dart';
import '../../core/security/security_history_service.dart';
import 'app_providers.dart';

final securityAuditorServiceProvider = Provider<SecurityAuditorService>((ref) {
  return SecurityAuditorService();
});

final securityHistoryServiceProvider = Provider<SecurityHistoryService>((ref) {
  return SecurityHistoryService();
});

final securityFixServiceProvider = Provider<SecurityFixService>((ref) {
  final history = ref.watch(securityHistoryServiceProvider);
  return SecurityFixService(historyService: history);
});

final securityHistoryListProvider = FutureProvider<List<SecurityAuditReport>>((ref) async {
  final history = ref.watch(securityHistoryServiceProvider);
  return history.loadReports();
});

class SecurityAuditState {
  final bool isScanning;
  final String scanningStage;
  final SecurityAuditReport? currentReport;
  final int activeWorkflowStep; // 1 to 7
  final String? errorMessage;

  const SecurityAuditState({
    this.isScanning = false,
    this.scanningStage = '',
    this.currentReport,
    this.activeWorkflowStep = 1,
    this.errorMessage,
  });

  SecurityAuditState copyWith({
    bool? isScanning,
    String? scanningStage,
    SecurityAuditReport? currentReport,
    int? activeWorkflowStep,
    String? errorMessage,
  }) {
    return SecurityAuditState(
      isScanning: isScanning ?? this.isScanning,
      scanningStage: scanningStage ?? this.scanningStage,
      currentReport: currentReport ?? this.currentReport,
      activeWorkflowStep: activeWorkflowStep ?? this.activeWorkflowStep,
      errorMessage: errorMessage,
    );
  }
}

class SecurityAuditNotifier extends StateNotifier<SecurityAuditState> {
  final Ref _ref;

  SecurityAuditNotifier(this._ref) : super(const SecurityAuditState()) {
    _loadLatestAudit();
  }

  Future<void> _loadLatestAudit() async {
    try {
      final history = await _ref.read(securityHistoryServiceProvider).loadReports();
      if (history.isNotEmpty && state.currentReport == null) {
        state = state.copyWith(
          currentReport: history.first,
          activeWorkflowStep: 3, // Reviewed findings
        );
      }
    } catch (_) {}
  }

  /// Runs the complete security audit across all 23 categories.
  Future<void> runCompleteAudit() async {
    state = state.copyWith(
      isScanning: true,
      activeWorkflowStep: 1, // 01 SCAN
      scanningStage: 'Scanning client API keys, auth flows, and secrets...',
      errorMessage: null,
    );

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(
        scanningStage: 'Checking PostgreSQL RLS policies & anonymous probes...',
        activeWorkflowStep: 2, // 02 WHAT NEEDS CHECKING
      );

      final auditor = _ref.read(securityAuditorServiceProvider);
      final report = await auditor.runFullAudit();

      // Save to audit history
      await _ref.read(securityHistoryServiceProvider).saveReport(report);
      _ref.invalidate(securityHistoryListProvider);

      state = state.copyWith(
        isScanning: false,
        scanningStage: '',
        currentReport: report,
        activeWorkflowStep: 3, // 03 REVIEW FINDINGS
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        scanningStage: '',
        errorMessage: 'Security audit failed: $e',
      );
    }
  }

  /// Applies an administrator-approved fix and re-verifies.
  Future<bool> applyApprovedFix(SecurityFinding finding) async {
    final user = _ref.read(currentUserProvider);
    final adminEmail = user?.email ?? 'admin@benchmark-mms.internal';

    state = state.copyWith(
      isScanning: true,
      activeWorkflowStep: 5, // 05 APPLY FIXES
      scanningStage: 'Applying approved fix for ${finding.id}...',
    );

    try {
      final fixService = _ref.read(securityFixServiceProvider);
      final isVerified = await fixService.applyApprovedFix(
        finding: finding,
        administratorEmail: adminEmail,
      );

      // Re-save updated report to history
      if (state.currentReport != null) {
        await _ref.read(securityHistoryServiceProvider).saveReport(state.currentReport!);
        _ref.invalidate(securityHistoryListProvider);
      }

      state = state.copyWith(
        isScanning: false,
        scanningStage: '',
        activeWorkflowStep: isVerified ? 6 : 4, // 06 VERIFY or back to APPROVE
      );

      return isVerified;
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        scanningStage: '',
        errorMessage: 'Failed to apply fix: $e',
      );
      return false;
    }
  }

  void setWorkflowStep(int step) {
    state = state.copyWith(activeWorkflowStep: step);
  }
}

final securityAuditStateProvider =
    StateNotifierProvider<SecurityAuditNotifier, SecurityAuditState>((ref) {
  return SecurityAuditNotifier(ref);
});
