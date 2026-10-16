import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../data/models/invoice_model.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../data/models/transfer_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';
import '../widgets/owner_report_components.dart';

class OwnerAdminSectionScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onBackToDashboard;

  const OwnerAdminSectionScreen({
    super.key,
    this.initialTabIndex = 0,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OwnerAdminSectionScreen> createState() => _OwnerAdminSectionScreenState();
}

class _OwnerAdminSectionScreenState extends ConsumerState<OwnerAdminSectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search controllers
  final TextEditingController _liveStockSearchCtrl = TextEditingController();
  final TextEditingController _invoicesSearchCtrl = TextEditingController();
  final TextEditingController _transfersSearchCtrl = TextEditingController();

  String _liveStockSearch = '';
  String _invoicesSearch = '';
  String _transfersSearch = '';

  // Invoices Date Filter (defaults to Today)
  OwnerQuickDateFilter _invoicesDateFilter = OwnerQuickDateFilter.today;
  DateTime? _invoicesCustomFrom;
  DateTime? _invoicesCustomTo;

  // Transfers Filter
  String _transfersDeptFilter = 'ALL'; // 'ALL', 'TEA', 'CHOCOLATE'
  OwnerQuickDateFilter _transfersDateFilter = OwnerQuickDateFilter.allTime;
  DateTime? _transfersCustomFrom;
  DateTime? _transfersCustomTo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveStockSearchCtrl.dispose();
    _invoicesSearchCtrl.dispose();
    _transfersSearchCtrl.dispose();
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

  Future<void> _pickCustomDateRange({required bool isInvoices}) async {
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
              primary: Color(0xFFF59E0B),
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isInvoices) {
          _invoicesDateFilter = OwnerQuickDateFilter.custom;
          _invoicesCustomFrom = picked.start;
          _invoicesCustomTo = picked.end;
        } else {
          _transfersDateFilter = OwnerQuickDateFilter.custom;
          _transfersCustomFrom = picked.start;
          _transfersCustomTo = picked.end;
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
                  _buildLiveStockTab(isTablet),
                  _buildTodayInvoicesTab(isTablet),
                  _buildTransfersTab(isTablet),
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
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Operations Reporting',
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 17 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Live Stock • Today\'s Invoices • Department Transfers (Read-Only)',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Exactly 3 Tabs: Live Stock, Today's Invoices, Transfers
          TabBar(
            controller: _tabController,
            isScrollable: !isTablet,
            tabAlignment: isTablet ? TabAlignment.start : TabAlignment.start,
            indicatorColor: const Color(0xFFF59E0B),
            indicatorWeight: 3,
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Live Stock',
              ),
              Tab(
                icon: Icon(Icons.receipt_long_outlined, size: 18),
                text: 'Today\'s Invoices',
              ),
              Tab(
                icon: Icon(Icons.swap_horiz_rounded, size: 18),
                text: 'Transfers',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1: LIVE STOCK
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildLiveStockTab(bool isTablet) {
    final liveStockAsync = ref.watch(ownerAdminLiveStockProvider(_liveStockSearch));

    return liveStockAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Admin Live Stock',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerAdminLiveStockProvider),
        ),
      ),
      data: (items) {
        // Compute summary totals
        double totalAdminStock = 0.0;
        double totalTransferredStock = 0.0;
        double totalTeaTransferred = 0.0;
        double totalChocTransferred = 0.0;

        for (final item in items) {
          totalAdminStock += item.adminStock;
          totalTransferredStock += item.totalTransferred;
          totalTeaTransferred += item.teaStock;
          totalChocTransferred += item.chocolateStock;
        }

        final totalEnterpriseStock = totalAdminStock + totalTransferredStock;

        return RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerAdminLiveStockProvider);
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
                      label: 'TOTAL MATERIALS',
                      value: '${items.length}',
                      subtitle: 'In Material Master',
                      icon: Icons.category_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'ADMIN WAREHOUSE STOCK',
                      value: QuantityFormatter.formatClean(totalAdminStock),
                      subtitle: 'Currently Held by Admin',
                      icon: Icons.warehouse_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'TRANSFERRED TO DEPTS',
                      value: QuantityFormatter.formatClean(totalTransferredStock),
                      subtitle: 'Tea: ${QuantityFormatter.formatClean(totalTeaTransferred)} • Choc: ${QuantityFormatter.formatClean(totalChocTransferred)}',
                      icon: Icons.move_to_inbox_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL ENTERPRISE STOCK',
                      value: QuantityFormatter.formatClean(totalEnterpriseStock),
                      subtitle: 'Admin + All Departments',
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                OwnerSearchBar(
                  controller: _liveStockSearchCtrl,
                  hintText: 'Search material code, description, category...',
                  onChanged: (val) {
                    setState(() => _liveStockSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Live Stock List / Table
                if (items.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.inventory_2_outlined,
                    title: 'No materials found',
                    message: 'No stock records match the specified search query.',
                  )
                else
                  ...items.map((item) => _buildLiveStockCard(item)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveStockCard(OwnerAdminLiveStockItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.hasAdminStock ? const Color(0xFF1F2937) : const Color(0xFF374151).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code, Category, Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.materialCode,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.category.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                ),
              ),
              const Spacer(),
              Text(
                'Unit: ${item.unit}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            item.description,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),

          // Two stock pillars: Stock held by Admin vs Stock Transferred to other departments
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                // Pillar 1: Admin Warehouse
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warehouse_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            'Held by Admin',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.formattedAdminStock,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.hasAdminStock ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFF334155)),
                const SizedBox(width: 12),

                // Pillar 2: Transferred to departments
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'Transferred Out',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.formattedTransferred,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: item.hasTransferred ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transferred details breakdown (Tea vs Chocolate) if transferred
          if (item.hasTransferred) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  if (item.teaStock > 0.0001)
                    Text(
                      'Tea Dept: ${item.formattedTeaStock}   ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w500),
                    ),
                  if (item.chocolateStock > 0.0001)
                    Text(
                      'Chocolate Dept: ${item.formattedChocolateStock}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFD97706), fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Last transaction date and time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Last Tx: ${item.formattedLastTxDate} ${item.formattedLastTxTime}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
              Text(
                'Total: ${item.formattedTotalStock}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2: TODAY'S INVOICES
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTodayInvoicesTab(bool isTablet) {
    final range = _resolveDateRange(_invoicesDateFilter, _invoicesCustomFrom, _invoicesCustomTo);
    final invoicesAsync = ref.watch(
      ownerInvoicesReportProvider((fromDate: range.from, toDate: range.to, search: _invoicesSearch)),
    );

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Invoices Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerInvoicesReportProvider),
        ),
      ),
      data: (invoices) {
        double totalInvoicedAmount = 0.0;
        int totalItemsInvoiced = 0;

        for (final inv in invoices) {
          totalInvoicedAmount += inv.finalTotal;
          totalItemsInvoiced += inv.items.length;
        }

        return RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerInvoicesReportProvider);
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
                      label: 'INVOICES RECORDED',
                      value: '${invoices.length}',
                      subtitle: _invoicesDateFilter == OwnerQuickDateFilter.today ? 'Received Today' : 'For Selected Period',
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    OwnerKpiChip(
                      label: 'TOTAL INVOICE AMOUNT',
                      value: '₹${QuantityFormatter.formatClean(totalInvoicedAmount)}',
                      subtitle: 'Inclusive of All Taxes',
                      icon: Icons.currency_rupee_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'LINE ITEMS RECEIVED',
                      value: '$totalItemsInvoiced',
                      subtitle: 'Material Lines Inwarded',
                      icon: Icons.list_alt_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _invoicesDateFilter,
                  onSelected: (filter) {
                    setState(() {
                      _invoicesDateFilter = filter;
                    });
                  },
                  onPickCustom: () => _pickCustomDateRange(isInvoices: true),
                  customFrom: _invoicesCustomFrom,
                  customTo: _invoicesCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _invoicesSearchCtrl,
                  hintText: 'Search invoice number or vendor...',
                  onChanged: (val) {
                    setState(() => _invoicesSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Invoices List
                if (invoices.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: _invoicesDateFilter == OwnerQuickDateFilter.today
                        ? 'No invoices recorded today'
                        : 'No invoices found for this period',
                    message: 'Any inward purchase invoices recorded by Admin will display here.',
                  )
                else
                  ...invoices.map((inv) => _buildInvoiceCard(inv)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCard(InvoiceModel inv) {
    // Concise material summary: e.g. "PEPPER B (20 KG)" or "PEPPER B, GINGER (2 items)"
    String materialSummary = '—';
    String totalQuantityStr = '';
    if (inv.items.isNotEmpty) {
      if (inv.items.length == 1) {
        final item = inv.items.first;
        materialSummary = item.material;
        totalQuantityStr = '${QuantityFormatter.formatClean(item.quantity)} ${item.unit}';
      } else {
        materialSummary = '${inv.items.first.material} + ${inv.items.length - 1} more items';
        final sumQty = inv.items.fold<double>(0.0, (acc, item) => acc + item.quantity);
        totalQuantityStr = '${QuantityFormatter.formatClean(sumQty)} total';
      }
    }

    return InkWell(
      onTap: () => showOwnerInvoiceDetailsModal(context, inv),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${inv.invoiceNo.isNotEmpty ? inv.invoiceNo : inv.id}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      inv.vendor.isNotEmpty ? inv.vendor : 'Vendor Unspecified',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  '₹${QuantityFormatter.formatClean(inv.finalTotal)}',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Material Summary row
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    materialSummary,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (totalQuantityStr.isNotEmpty)
                  Text(
                    totalQuantityStr,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Date, Time & tap prompt
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppDateFormatter.format(inv.date)} • ${AppDateFormatter.formatTime(inv.effectiveDateTime)}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    Text(
                      'View Details',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFF59E0B)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3: TRANSFERS
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildTransfersTab(bool isTablet) {
    final range = _resolveDateRange(_transfersDateFilter, _transfersCustomFrom, _transfersCustomTo);
    final transfersAsync = ref.watch(
      ownerTransfersReportProvider((
        department: _transfersDeptFilter,
        fromDate: range.from,
        toDate: range.to,
        search: _transfersSearch,
      )),
    );

    return transfersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B))),
      error: (err, _) => Center(
        child: EmptyStateWidget(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load Transfers Report',
          message: err.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(ownerTransfersReportProvider),
        ),
      ),
      data: (transfers) {
        double totalToTea = 0.0;
        double totalToChocolate = 0.0;

        for (final t in transfers) {
          final dept = t.department.trim().toUpperCase();
          final net = t.outward - t.returnUnits;
          if (dept == 'TEA') {
            totalToTea += net;
          } else if (dept == 'CHOCOLATE') {
            totalToChocolate += net;
          }
        }

        return RefreshIndicator(
          color: const Color(0xFFF59E0B),
          backgroundColor: const Color(0xFF1E293B),
          onRefresh: () async {
            ref.invalidate(ownerTransfersReportProvider);
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
                      label: 'TOTAL TRANSFERS',
                      value: '${transfers.length}',
                      subtitle: 'Transfers Recorded',
                      icon: Icons.swap_horiz_rounded,
                      accentColor: const Color(0xFF06B6D4),
                    ),
                    OwnerKpiChip(
                      label: 'TRANSFERRED TO TEA',
                      value: QuantityFormatter.formatClean(totalToTea),
                      subtitle: 'Net Quantity to Tea',
                      icon: Icons.eco_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    OwnerKpiChip(
                      label: 'TRANSFERRED TO CHOCOLATE',
                      value: QuantityFormatter.formatClean(totalToChocolate),
                      subtitle: 'Net Quantity to Chocolate',
                      icon: Icons.cookie_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Department Filter Pills
                Row(
                  children: [
                    _buildDeptFilterPill('All Departments', 'ALL'),
                    const SizedBox(width: 8),
                    _buildDeptFilterPill('To Tea', 'TEA'),
                    const SizedBox(width: 8),
                    _buildDeptFilterPill('To Chocolate', 'CHOCOLATE'),
                  ],
                ),
                const SizedBox(height: 10),

                // Date Filter Chips
                OwnerDateFilterChips(
                  selected: _transfersDateFilter,
                  onSelected: (filter) {
                    setState(() => _transfersDateFilter = filter);
                  },
                  onPickCustom: () => _pickCustomDateRange(isInvoices: false),
                  customFrom: _transfersCustomFrom,
                  customTo: _transfersCustomTo,
                ),
                const SizedBox(height: 12),

                // Search Bar
                OwnerSearchBar(
                  controller: _transfersSearchCtrl,
                  hintText: 'Search material code, description, recipient...',
                  onChanged: (val) {
                    setState(() => _transfersSearch = val.trim());
                  },
                ),
                const SizedBox(height: 14),

                // Transfers List
                if (transfers.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.swap_horiz_rounded,
                    title: 'No transfers recorded for this period',
                    message: 'Material transfers from Admin to Tea or Chocolate will display here.',
                  )
                else
                  ...transfers.map((t) => _buildTransferCard(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeptFilterPill(String label, String dept) {
    final isSelected = _transfersDeptFilter == dept;
    return InkWell(
      onTap: () {
        setState(() => _transfersDeptFilter = dept);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferCard(TransferModel t) {
    final isTea = t.department.trim().toUpperCase() == 'TEA';
    final isChoc = t.department.trim().toUpperCase() == 'CHOCOLATE';
    final isReturn = t.returnUnits > 0.0001;

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
          // Row: Date/Time + Status Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppDateFormatter.format(t.date)} ${AppDateFormatter.formatTime(t.effectiveDateTime)}',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReturn
                      ? const Color(0xFF06B6D4).withValues(alpha: 0.15)
                      : (isTea ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isReturn ? 'RETURN TO ADMIN' : 'COMPLETED OUTWARD',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isReturn
                        ? const Color(0xFF06B6D4)
                        : (isTea ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Material Name & Code
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.code,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.description,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Text(
                '${QuantityFormatter.formatClean(t.outward > 0 ? t.outward : t.returnUnits)} ${t.units}',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Department Movement Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Text(
                  isReturn ? t.department.toUpperCase() : 'ADMIN WAREHOUSE',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Text(
                  isReturn ? 'ADMIN WAREHOUSE' : t.department.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTea ? const Color(0xFF10B981) : (isChoc ? const Color(0xFFF59E0B) : Colors.white),
                  ),
                ),
                const Spacer(),
                if (t.person.isNotEmpty)
                  Text(
                    'Op: ${t.person}',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
