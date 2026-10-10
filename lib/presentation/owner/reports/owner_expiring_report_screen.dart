import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/search_bar_widget.dart';
import '../../providers/inventory_settings_provider.dart';
import '../../providers/owner_providers.dart';

/// Owner Expiry Report providing strict, independent separation between
/// Invoice Raw Materials and Storage Finished Products with their independent thresholds.
class OwnerExpiringReportScreen extends ConsumerStatefulWidget {
  const OwnerExpiringReportScreen({super.key});

  @override
  ConsumerState<OwnerExpiringReportScreen> createState() => _OwnerExpiringReportScreenState();
}

class _OwnerExpiringReportScreenState extends ConsumerState<OwnerExpiringReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(inventorySettingsProvider).valueOrNull;
    final invDays = settings?.invoiceMaterialExpiryAlertDays ?? 30;
    final storDays = settings?.storageProductExpiryAlertDays ?? 30;
    final summaryAsync = ref.watch(ownerDashboardSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Expiring Items Monitor',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(ownerDashboardSummaryProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Invoice Materials ($invDays Days)'),
            Tab(text: 'Storage Products ($storDays Days)'),
          ],
        ),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBarWidget(
                hintText: 'Search code, product, or lot...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),

            Expanded(
              child: summaryAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (e, _) => Center(
                  child: Text('Error loading expiry report: $e', style: const TextStyle(color: AppColors.danger)),
                ),
                data: (summary) {
                  final invList = summary.expiryMonitor.invoiceMaterials;
                  final storList = summary.expiryMonitor.storageProducts;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Invoice Materials
                      _buildMaterialsExpiryList(invList, invDays),
                      // Tab 2: Storage Finished Products
                      _buildStorageExpiryList(storList, storDays),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsExpiryList(List<dynamic> items, int thresholdDays) {
    final filtered = items.where((it) {
      if (_search.isEmpty) return true;
      final code = it['material_code']?.toString().toLowerCase() ?? '';
      final desc = it['description']?.toString().toLowerCase() ?? '';
      return code.contains(_search) || desc.contains(_search);
    }).toList();

    final expired = filtered.where((it) => (it['days_remaining'] as num? ?? 0) < 0).toList();
    final upcoming = filtered.where((it) => (it['days_remaining'] as num? ?? 0) >= 0).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.timer_outlined,
        title: 'No Expiring Materials',
        message: 'No raw materials are approaching expiry within $thresholdDays days.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Source Tag Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'SOURCE: INVOICE MATERIAL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
              ),
              Text(
                'Threshold: $thresholdDays Days',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (expired.isNotEmpty) ...[
          _buildSectionHeader('EXPIRED MATERIALS (${expired.length})', AppColors.danger),
          ...expired.map((it) => _buildMaterialExpiryCard(it, isExpired: true)),
          const SizedBox(height: 16),
        ],

        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('UPCOMING EXPIRY (${upcoming.length})', const Color(0xFFF97316)),
          ...upcoming.map((it) => _buildMaterialExpiryCard(it, isExpired: false)),
        ],
      ],
    );
  }

  Widget _buildStorageExpiryList(List<dynamic> items, int thresholdDays) {
    final filtered = items.where((it) {
      if (_search.isEmpty) return true;
      final code = it['material_code']?.toString().toLowerCase() ?? '';
      final desc = it['description']?.toString().toLowerCase() ?? '';
      final batch = it['batch_no']?.toString().toLowerCase() ?? '';
      return code.contains(_search) || desc.contains(_search) || batch.contains(_search);
    }).toList();

    final expired = filtered.where((it) => (it['days_remaining'] as num? ?? 0) < 0).toList();
    final upcoming = filtered.where((it) => (it['days_remaining'] as num? ?? 0) >= 0).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.inventory_2_outlined,
        title: 'No Expiring Storage Products',
        message: 'No storage finished batches are approaching expiry within $thresholdDays days.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Source Tag Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text(
                'SOURCE: STORAGE PRODUCT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
              ),
              Text(
                'Threshold: $thresholdDays Days',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (expired.isNotEmpty) ...[
          _buildSectionHeader('EXPIRED STORAGE BATCHES (${expired.length})', AppColors.danger),
          ...expired.map((it) => _buildStorageExpiryCard(it, isExpired: true)),
          const SizedBox(height: 16),
        ],

        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('UPCOMING EXPIRY (${upcoming.length})', const Color(0xFFF97316)),
          ...upcoming.map((it) => _buildStorageExpiryCard(it, isExpired: false)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialExpiryCard(Map<String, dynamic> item, {required bool isExpired}) {
    final code = item['material_code']?.toString() ?? '';
    final desc = item['description']?.toString() ?? code;
    final cat = item['category']?.toString() ?? 'General';
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
    final unit = item['unit']?.toString() ?? 'kg';
    final expiry = item['expiry_date']?.toString() ?? '-';
    final days = (item['days_remaining'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpired ? AppColors.danger.withValues(alpha: 0.4) : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isExpired ? AppColors.danger : const Color(0xFFF97316)).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.cancel_outlined : Icons.timer_outlined,
              size: 20,
              color: isExpired ? AppColors.danger : const Color(0xFFF97316),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      code,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Expiry: $expiry (${isExpired ? '${-days} days ago' : '$days days left'})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? AppColors.danger : const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                QuantityFormatter.formatClean(qty),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                unit,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageExpiryCard(Map<String, dynamic> item, {required bool isExpired}) {
    final batch = item['batch_no']?.toString() ?? '';
    final code = item['material_code']?.toString() ?? '';
    final desc = item['description']?.toString() ?? code;
    final qty = (item['available_quantity'] as num?)?.toDouble() ?? 0.0;
    final uom = item['uom']?.toString() ?? 'kg';
    final expiry = item['expiry_date']?.toString() ?? '-';
    final days = (item['days_remaining'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpired ? AppColors.danger.withValues(alpha: 0.4) : const Color(0xFF334155),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isExpired ? AppColors.danger : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.cancel_outlined : Icons.layers_outlined,
              size: 20,
              color: isExpired ? AppColors.danger : const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      'Batch: $batch',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Expiry: $expiry (${isExpired ? '${-days} days ago' : '$days days left'})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? AppColors.danger : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                QuantityFormatter.formatClean(qty),
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                uom,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
