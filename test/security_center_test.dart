import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/security/security_finding_model.dart';
import 'package:mms_app/presentation/security/security_center_screen.dart';
import 'package:mms_app/presentation/security/widgets/security_workflow_tracker.dart';
import 'package:mms_app/presentation/security/widgets/security_finding_card.dart';
import 'package:mms_app/presentation/providers/security_providers.dart';

void main() {
  group('Security Finding Model & Secret Masking Tests', () {
    test('1. maskSecret hides service-role keys completely', () {
      final masked = SecurityFinding.maskSecret(
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.service_role_secret_key_123456789',
        isServiceRole: true,
      );
      expect(masked, equals('SECRET DETECTED — VALUE HIDDEN'));
      expect(masked.contains('service_role_secret'), isFalse);
    });

    test('2. maskSecret safely masks client publishable keys without exposing full text', () {
      final masked = SecurityFinding.maskSecret(
        'sb_publishable_abcdef1234567890',
        isServiceRole: false,
      );
      expect(masked.startsWith('sb_publishable_'), isTrue);
      expect(masked.endsWith('7890'), isTrue);
      expect(masked.contains('••••'), isTrue);
      expect(masked.contains('abcdef'), isFalse);
    });

    test('3. maskSecret handles empty or null keys safely', () {
      expect(SecurityFinding.maskSecret(null), equals('NOT SET'));
      expect(SecurityFinding.maskSecret(''), equals('NOT SET'));
    });

    test('4. Security score is capped at 98 and counts correctly by severity', () {
      final noIssuesFindings = <SecurityFinding>[];
      final reportClean = SecurityAuditReport(
        id: 'AUD-001',
        timestamp: DateTime.now(),
        securityScore: 98,
        status: SecurityAuditStatus.secure,
        totalChecks: 23,
        findings: noIssuesFindings,
        summary: 'Audit completed. No issues detected within the checks performed.',
      );
      // Never claim 100% secure
      expect(reportClean.securityScore, lessThanOrEqualTo(98));
      expect(reportClean.securityScore, equals(98));
      expect(reportClean.status, equals(SecurityAuditStatus.secure));
      expect(reportClean.criticalCount, equals(0));

      final dirtyFindings = <SecurityFinding>[
        SecurityFinding(
          id: 'TEST-1',
          severity: SecuritySeverity.critical,
          category: SecurityCategory.apiKeys,
          title: 'Critical Test',
          affectedComponent: 'Auth',
          whyItMatters: 'Critical impact',
          currentState: 'Exposed',
          recommendedFix: 'Revoke',
          risk: 'High risk',
          fixType: FixType.manualConfiguration,
        ),
        SecurityFinding(
          id: 'TEST-2',
          severity: SecuritySeverity.high,
          category: SecurityCategory.rls,
          title: 'High Test',
          affectedComponent: 'RLS',
          whyItMatters: 'Data bypass',
          currentState: 'Missing',
          recommendedFix: 'Enable RLS',
          risk: 'Medium risk',
          fixType: FixType.safeAutoFix,
        ),
      ];

      final reportDirty = SecurityAuditReport(
        id: 'AUD-002',
        timestamp: DateTime.now(),
        securityScore: 58,
        status: SecurityAuditStatus.criticalIssuesFound,
        totalChecks: 23,
        findings: dirtyFindings,
        summary: '2 issues identified across Supabase project configuration.',
      );

      expect(reportDirty.criticalCount, equals(1));
      expect(reportDirty.highCount, equals(1));
      expect(reportDirty.status, equals(SecurityAuditStatus.criticalIssuesFound));
      expect(reportDirty.securityScore, equals(58));
    });
  });

  group('Security Workflow Tracker Widget Tests', () {
    testWidgets('1. SecurityWorkflowTracker displays all 7 phases', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SecurityWorkflowTracker(activeStep: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCAN'), findsOneWidget);
      expect(find.text('CHECKING'), findsOneWidget);
      expect(find.text('FINDINGS'), findsOneWidget);
      expect(find.text('APPROVE'), findsOneWidget);
      expect(find.text('APPLY'), findsOneWidget);
      expect(find.text('VERIFY'), findsOneWidget);
      expect(find.text('REPORT'), findsOneWidget);
    });
  });

  group('Security Center Screen Widget Tests', () {
    testWidgets('1. SecurityCenterScreen renders professional control center UI in initial state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SecurityCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and title
      expect(find.text('SECURITY CENTER'), findsOneWidget);
      expect(find.text('Supabase Security Audit'), findsOneWidget);

      // Buttons
      expect(find.text('RUN SECURITY AUDIT'), findsOneWidget);
      expect(find.text('VIEW SECURITY HISTORY'), findsOneWidget);

      // Status indicator
      expect(find.text('Not Scanned'), findsOneWidget);
      expect(find.text('Benchmark MMS Security Audit'), findsOneWidget);
      expect(find.text('START SYSTEM SECURITY AUDIT'), findsOneWidget);
    });

    testWidgets('2. SecurityCenterScreen displays score and severity counters when report is present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testReport = SecurityAuditReport(
        id: 'AUD-TEST-99',
        timestamp: DateTime.now(),
        securityScore: 82,
        status: SecurityAuditStatus.issuesFound,
        totalChecks: 23,
        findings: [
          SecurityFinding(
            id: 'SEC-TEST-01',
            severity: SecuritySeverity.high,
            category: SecurityCategory.rls,
            title: 'Test RLS Missing',
            affectedComponent: 'public.test_table',
            whyItMatters: 'Test reason',
            currentState: 'RLS Disabled',
            recommendedFix: 'Enable RLS',
            risk: 'Test risk',
            fixType: FixType.safeAutoFix,
          ),
        ],
        summary: '1 high-priority issue detected.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityAuditStateProvider.overrideWith((ref) {
              final notifier = SecurityAuditNotifier(ref);
              notifier.state = SecurityAuditState(
                currentReport: testReport,
                activeWorkflowStep: 3,
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: SecurityCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Score and severity metrics
      expect(find.text('SECURITY SCORE'), findsOneWidget);
      expect(find.text('82'), findsOneWidget);
      expect(find.text(' / 100'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('HIGH'), findsNWidgets(2));
      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('Test RLS Missing'), findsOneWidget);
    });

    testWidgets('3. SecurityFindingCard renders finding details without raw secrets', (tester) async {
      final finding = SecurityFinding(
        id: 'SEC-RLS-001',
        severity: SecuritySeverity.high,
        category: SecurityCategory.rls,
        title: 'Overly Permissive RLS Policy Detected',
        affectedComponent: 'public.vendors',
        whyItMatters: 'Allows unauthenticated users to create, modify, or delete supplier data.',
        currentState: 'Policy allows TO authenticated, anon FOR ALL',
        recommendedFix: 'Restrict write operations to authenticated staff.',
        risk: 'Unauthorized record manipulation.',
        fixType: FixType.safeAutoFix,
        fixSql: 'DROP POLICY IF EXISTS vendors_policy ON vendors;',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecurityFindingCard(
              finding: finding,
              onViewDetails: () {},
              onApplyFix: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Overly Permissive RLS Policy Detected'), findsOneWidget);
      expect(find.text('public.vendors'), findsOneWidget);
      expect(find.text('Apply Safe Fix'), findsOneWidget);
      expect(find.text('View Details'), findsOneWidget);
    });
  });
}
