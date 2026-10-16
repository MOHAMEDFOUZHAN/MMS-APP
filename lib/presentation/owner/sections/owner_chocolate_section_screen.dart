import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../data/models/batch_model.dart';
import '../../../data/models/chocolate_ocr_ledger_model.dart';
import '../../../data/models/dispatch_model.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';
import '../widgets/owner_report_components.dart';

class OwnerChocolateSectionScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onBackToDashboard;

  const OwnerChocolateSectionScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OwnerChocolateSectionScreen> createState() => _OwnerChocolateSectionScreenState();
}

class _OwnerChocolateSectionScreenState extends ConsumerState<OwnerChocolateSectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search controllers
  final TextEditingController _liveMaterialSearchCtrl = TextEditingController();
  final TextEditingController _ocrSearchCtrl = TextEditingController();
  final TextEditingController _rackSearchCtrl = TextEditingController();
  final TextEditingController _consignSearchCtrl = TextEditingController();

  String _liveMaterialSearch = '';
  String _ocrSearch = '';
  String _rackSearch = '';
  String _consignSearch = '';

  // OCR Date Filter
  OwnerQuickDateFilter _ocrDateFilter = OwnerQuickDateFilter.allTime;
  DateTime? _ocrCustomFrom;
  DateTime? _ocrCustomTo;

  // Consignment Date Filter
  OwnerQuickDateFilter _consignDateFilter = OwnerQuickDateFilter.allTime;
  DateTime? _consignCustomFrom;
  DateTime? _consignCustomTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveMaterialSearchCtrl.dispose();
    _ocrSearchCtrl.dispose();
    _rackSearchCtrl.dispose();
    _consignSearchCtrl.dispose();
    super.dispose();
  }

  ({DateTime? from, DateTime? to}) _resolveDateRange(
    OwnerQuickDateFilter filter,
    DateTime? customFrom,
    DateTime? customTo,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case OwnerQuickDateFilter.today:
        return (from: today, to: today);
      case OwnerQuickDateFilter.last7Days:
        return (from: today.subtract(const Duration(days: 7)), to: today);
      case OwnerQuickDateFilter.thisMonth:
        return (from: DateTime(now.year, now.month, 1), to: today);
      case OwnerQuickDateFilter.allTime:
        return (from: null, to: null);
      case OwnerQuickDateFilter.custom:
        return (from: customFrom, to: customTo);
    }
  }

  Future<void> _pickCustomDateRange({required bool isOcr}) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD97706),
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOcr) {
          _ocrDateFilter = OwnerQuickDateFilter.custom;
          _ocrCustomFrom = picked.start;
          _ocrCustomTo = picked.end;
        } else {
          _consignDateFilter = OwnerQuickDateFilter.custom;
          _consignCustomFrom = picked.start;
          _consignCustomTo = picked.end;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section Header & Tab Bar
            _buildTopSectionBar(isTablet),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLiveMaterialTab(isTablet),
                  _buildOcrTab(isTablet),
                  _buildRackTab(isTablet),
                  _buildConsignTab(isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSectionBar(bool isTablet) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.onBackToDashboard != null)
                InkWell(
                  onTap: widget.onBackToDashboard,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          'Portal Hub',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cookie_rounded, size: 20, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chocolate Section Reporting',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 17 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Live Materials • Confirmed OCR • Rack Inventory • Consignments (Read-Only)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Exactly 4 Tabs: Live Material, OCR Report, Rack Report, Consign Report
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFFD97706),
            indicatorWeight: 3,
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Chocolate Live Material',
              ),
              Tab(
                icon: Icon(Icons.document_scanner_outlined, size: 18),
                text: 'Chocolate OCR Report',
              ),
              Tab(
                icon: Icon(Icons.shelves, size: 18),
                text: 'Chocolate Rack Report',
              ),
              Tab(
                icon: Icon(Icons.local_shipping_outlined, size: 18),
                text: 'Chocolate Consignment Report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: CHOCOLATE LIVE MATERIAL (Only genuinely transferred to Chocolate)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildLiveMaterialTab(bool isTablet) {
    final liveMaterialsAsync = ref.watch(
      ownerChocolateLiveMaterialsProvider((search: _liveMaterialSearch, category: null)),
    );

    return liveMaterialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Chocolate Live Materials',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerChocolateLiveMaterialsProvider),
        ),
      ),
      data: (materials) {
        double totalReceived = 0.0;
        double totalAccounted = 0.0;
        double totalBalance = 0.0;

        for (final m in materials) {
          totalReceived += m.totalReceived;
          totalAccounted += m.totalAccounted;
          totalBalance += m.currentBalance;
        }

        return RefreshIndicator(
          color: const Color(0xFFD97706),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerChocolateLiveMaterialsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'ACTIVE CHOCOLATE MATERIALS',
                      value: '${materials.length}',
                      subtitle: 'Transferred from Admin',
                      icon: Icons.category_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL RECEIVED',
                      value: QuantityFormatter.formatClean(totalReceived),
                      subtitle: 'From Admin Warehouse',
                      icon: Icons.move_to_inbox_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                    OwnerKpiChip(
                      label: 'ACCOUNTED / RETURNED',
                      value: QuantityFormatter.formatClean(totalAccounted),
                      subtitle: 'Authorized Returns to Admin',
                      icon: Icons.assignment_return_rounded,
                      accentColor: const Color(0xFF94A3B8),
                    ),
                    OwnerKpiChip(
                      label: 'AVAILABLE CHOCOLATE BALANCE',
                      value: QuantityFormatter.formatClean(totalBalance),
                      subtitle: 'Available for Production',
                      icon: Icons.cookie_rounded,
                      accentColor: const Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                OwnerSearchBar(
                  controller: _liveMaterialSearchCtrl,
                  hintText: 'Search chocolate material code or name...',
                  onChanged: (val) {
                    setState(() => _liveMaterialSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Materials List
                if (materials.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.cookie_outlined,
                    title: 'No materials transferred to Chocolate',
                    message: 'Only materials actually transferred from Admin to Chocolate appear in this report.',
                  )
                else
                  ...materials.map((m) => _buildChocolateLiveMaterialCard(m)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChocolateLiveMaterialCard(OwnerChocolateLiveMaterialItem m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.hasStock ? const Color(0xFF1F2937) : const Color(0xFF374151).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.materialCode,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.category,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: m.hasStock
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF64748B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.hasStock ? 'IN STOCK' : 'ZERO BALANCE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: m.hasStock ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            m.description,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),

          // Ledger Stats Grid
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                _statColumn('Total Received', '${QuantityFormatter.formatClean(m.totalReceived)} ${m.unit}', const Color(0xFF38BDF8)),
                Container(width: 1, height: 28, color: const Color(0xFF334155)),
                _statColumn('Accounted/Returned', '${QuantityFormatter.formatClean(m.totalAccounted)} ${m.unit}', const Color(0xFF94A3B8)),
                Container(width: 1, height: 28, color: const Color(0xFF334155)),
                _statColumn('Available Balance', '${QuantityFormatter.formatClean(m.currentBalance)} ${m.unit}', const Color(0xFFD97706), isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (m.latestActivity != null)
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Last Transaction: ${m.formattedLastTxDate} ${m.formattedLastTxTime}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color, {bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: CHOCOLATE OCR REPORT (Confirmed Weighing Records Only)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildOcrTab(bool isTablet) {
    final range = _resolveDateRange(_ocrDateFilter, _ocrCustomFrom, _ocrCustomTo);
    final ocrAsync = ref.watch(
      ownerConfirmedChocolateOcrProvider((fromDate: range.from, toDate: range.to, search: _ocrSearch)),
    );

    return ocrAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Chocolate OCR Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerConfirmedChocolateOcrProvider),
        ),
      ),
      data: (scans) {
        double totalCapturedWeight = 0.0;
        for (final s in scans) {
          totalCapturedWeight += s.quantity;
        }

        return RefreshIndicator(
          color: const Color(0xFFD97706),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerConfirmedChocolateOcrProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'CONFIRMED OCR SCANS',
                      value: '${scans.length}',
                      subtitle: 'Weighed & Confirmed Records',
                      icon: Icons.document_scanner_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL CAPTURED WEIGHT',
                      value: '${QuantityFormatter.formatClean(totalCapturedWeight)} KG',
                      subtitle: 'Authoritative Weighing Sum',
                      icon: Icons.scale_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _ocrDateFilter,
                  onSelected: (filter) {
                    setState(() => _ocrDateFilter = filter);
                  },
                  onPickCustom: () => _pickCustomDateRange(isOcr: true),
                  customFrom: _ocrCustomFrom,
                  customTo: _ocrCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _ocrSearchCtrl,
                  hintText: 'Search product name, code, document...',
                  onChanged: (val) {
                    setState(() => _ocrSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // OCR Scans List
                if (scans.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.document_scanner_outlined,
                    title: 'No confirmed OCR records found',
                    message: 'Successfully confirmed weighing records from Chocolate OCR terminal will appear here.',
                  )
                else
                  ...scans.map((s) => _buildOcrCard(s)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOcrCard(ChocolateOcrLedgerModel s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${s.formattedDate} • ${s.formattedTime}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.status.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.description,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ref ID: ${s.productCode} (#${s.id})',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Text(
                s.displayQuantity,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
            ],
          ),
          if (s.documentName != null && s.documentName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.camera_alt_outlined, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    s.documentName!,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: CHOCOLATE RACK REPORT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildRackTab(bool isTablet) {
    final rackAsync = ref.watch(ownerChocolateRackReportProvider(_rackSearch));

    return rackAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Chocolate Rack Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerChocolateRackReportProvider),
        ),
      ),
      data: (batches) {
        double totalAvailable = 0.0;
        int activeCount = 0;
        int depletedCount = 0;

        for (final b in batches) {
          totalAvailable += b.availableQuantity;
          if (b.availableQuantity > 0.0001) {
            activeCount++;
          } else {
            depletedCount++;
          }
        }

        return RefreshIndicator(
          color: const Color(0xFFD97706),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerChocolateRackReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'STORED RACK BATCHES',
                      value: '${batches.length}',
                      subtitle: 'Recorded in Rack',
                      icon: Icons.shelves,
                      accentColor: const Color(0xFFD97706),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL STORED WEIGHT / QTY',
                      value: QuantityFormatter.formatClean(totalAvailable),
                      subtitle: 'Available Finished Goods',
                      icon: Icons.inventory_2_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'ACTIVE / OUT OF STOCK',
                      value: '$activeCount / $depletedCount',
                      subtitle: 'Rack Stock Status',
                      icon: Icons.pie_chart_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                OwnerSearchBar(
                  controller: _rackSearchCtrl,
                  hintText: 'Search product name, rack location, batch no...',
                  onChanged: (val) {
                    setState(() => _rackSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Rack Batches List
                if (batches.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.shelves,
                    title: 'No products currently recorded in Chocolate Rack',
                    message: 'Finished goods physically placed into racks and trays by Chocolate department will appear here.',
                  )
                else
                  ...batches.map((b) => _buildRackBatchCard(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRackBatchCard(BatchModel b) {
    final hasStock = b.availableQuantity > 0.0001;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasStock ? const Color(0xFF1F2937) : const Color(0xFF374151).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'BATCH #${b.batchNo}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                    ),
                  ),
                  if (b.rackLocation != null && b.rackLocation!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shelves, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            b.rackLocation!,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasStock
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasStock ? 'IN RACK' : 'OUT OF STOCK',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  b.description.isNotEmpty ? b.description : b.materialCode,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(b.availableQuantity)} ${b.uom}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: hasStock ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Updated: ${AppDateFormatter.format(b.effectiveDateTime)} ${AppDateFormatter.formatTime(b.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              if (b.ocrLedgerId != null)
                Text(
                  'OCR Scan Ref #${b.ocrLedgerId}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 4: CHOCOLATE CONSIGNMENT REPORT
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildConsignTab(bool isTablet) {
    final range = _resolveDateRange(_consignDateFilter, _consignCustomFrom, _consignCustomTo);
    final consignAsync = ref.watch(
      ownerChocolateConsignmentReportProvider((fromDate: range.from, toDate: range.to, search: _consignSearch)),
    );

    return consignAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFD97706))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Chocolate Consignment Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerChocolateConsignmentReportProvider),
        ),
      ),
      data: (consignments) {
        double totalConsigned = 0.0;
        double netConsigned = 0.0;

        for (final c in consignments) {
          totalConsigned += c.quantity;
          netConsigned += c.netQuantity;
        }

        return RefreshIndicator(
          color: const Color(0xFFD97706),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerChocolateConsignmentReportProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Figures
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OwnerKpiChip(
                      label: 'TOTAL CONSIGNMENTS',
                      value: '${consignments.length}',
                      subtitle: 'Recorded Consignments',
                      icon: Icons.local_shipping_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL QUANTITY CONSIGNED',
                      value: QuantityFormatter.formatClean(totalConsigned),
                      subtitle: 'Gross Consigned Weight',
                      icon: Icons.outbox_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'NET CONSIGNMENT',
                      value: QuantityFormatter.formatClean(netConsigned),
                      subtitle: 'Net Delivered',
                      icon: Icons.done_all_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _consignDateFilter,
                  onSelected: (filter) {
                    setState(() => _consignDateFilter = filter);
                  },
                  onPickCustom: () => _pickCustomDateRange(isOcr: false),
                  customFrom: _consignCustomFrom,
                  customTo: _consignCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _consignSearchCtrl,
                  hintText: 'Search product name, code, destination...',
                  onChanged: (val) {
                    setState(() => _consignSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Consignments List
                if (consignments.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.local_shipping_outlined,
                    title: _consignDateFilter == OwnerQuickDateFilter.today
                        ? 'No consignments recorded today'
                        : 'No consignments recorded for this period',
                    message: 'Chocolate finished goods consigned from Rack inventory will appear here.',
                  )
                else
                  ...consignments.map((c) => _buildConsignmentCard(c)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsignmentCard(DispatchModel c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppDateFormatter.format(c.date)} ${AppDateFormatter.formatTime(c.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CONSIGNED',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  c.product.isNotEmpty ? c.product : c.materialCode,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(c.quantity)} ${c.units}',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    c.location.isNotEmpty ? c.location : 'Consignment Destination',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (c.returnQuantity > 0.0001)
                Text(
                  'Net: ${QuantityFormatter.formatClean(c.netQuantity)} ${c.units}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
