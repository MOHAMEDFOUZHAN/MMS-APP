import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';

/// Page One — Live Stock
/// Unified read-only stock monitoring portal displaying all materials in one single page.
/// Columns: Code, Description, Current Stock, Unit.
class OwnerLiveStockScreen extends ConsumerStatefulWidget {
  const OwnerLiveStockScreen({super.key});

  @override
  ConsumerState<OwnerLiveStockScreen> createState() => _OwnerLiveStockScreenState();
}

class _OwnerLiveStockScreenState extends ConsumerState<OwnerLiveStockScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;
    final liveStockAsync = ref.watch(ownerLiveStockProvider(_searchQuery.isEmpty ? null : _searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header & Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, size: 18, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Stock',
                              style: GoogleFonts.inter(
                                fontSize: isWide ? 17 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'All materials across Admin, Tea, Chocolate, and Storage',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh Stock',
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                        onPressed: () => ref.invalidate(ownerLiveStockProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Simple Search Box
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by material code or description...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                ],
              ),
            ),

            // Content List / Table
            Expanded(
              child: liveStockAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                ),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load live stock',
                    message: err.toString(),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(ownerLiveStockProvider),
                  ),
                ),
                data: (materials) {
                  // Client-side search filtering
                  final filtered = _searchQuery.isEmpty
                      ? materials
                      : materials.where((m) {
                          final q = _searchQuery.toLowerCase();
                          return m.materialCode.toLowerCase().contains(q) ||
                              m.description.toLowerCase().contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: EmptyStateWidget(
                        icon: Icons.search_off_rounded,
                        title: 'No materials found',
                        message: _searchQuery.isEmpty
                            ? 'No stock records available.'
                            : 'No materials match "$_searchQuery".',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: () async {
                      ref.invalidate(ownerLiveStockProvider);
                    },
                    child: Column(
                      children: [
                        // Subtitle status line
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: const Color(0xFF0B0F19),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Showing ${filtered.length} materials',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Total Business Stock',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Header (Desktop / Tablet view)
                        if (isWide) _buildTableHeader(),

                        // List of items
                        Expanded(
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFF1E293B),
                            ),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return isWide
                                  ? _buildDesktopRow(item)
                                  : _buildMobileRow(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B)),
          bottom: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              'CODE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: Text(
              'DESCRIPTION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              'CURRENT STOCK',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 55,
            child: Text(
              'UNIT',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(OwnerAdminLiveStockItem item) {
    final hasStock = item.totalSystemStock > 0.0001;

    // Location breakdown text to clearly distinguish total stock from locations
    final parts = <String>[];
    if (item.adminStock > 0.0001) parts.add('Admin: ${QuantityFormatter.formatClean(item.adminStock)}');
    if (item.teaStock > 0.0001) parts.add('Tea: ${QuantityFormatter.formatClean(item.teaStock)}');
    if (item.chocolateStock > 0.0001) parts.add('Choc: ${QuantityFormatter.formatClean(item.chocolateStock)}');
    if (item.otherStock > 0.0001) parts.add('Other: ${QuantityFormatter.formatClean(item.otherStock)}');
    final breakdownText = parts.isEmpty ? 'No location stock' : parts.join(' • ');

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Code
          SizedBox(
            width: 85,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                item.materialCode,
                style: GoogleFonts.robotoMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF59E0B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Description
          Expanded(
            flex: 4,
            child: Text(
              item.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),

          // Current Stock
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      QuantityFormatter.formatClean(item.totalSystemStock),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  breakdownText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Unit
          SizedBox(
            width: 55,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.unit.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFCBD5E1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(OwnerAdminLiveStockItem item) {
    final hasStock = item.totalSystemStock > 0.0001;

    final parts = <String>[];
    if (item.adminStock > 0.0001) parts.add('Admin: ${QuantityFormatter.formatClean(item.adminStock)}');
    if (item.teaStock > 0.0001) parts.add('Tea: ${QuantityFormatter.formatClean(item.teaStock)}');
    if (item.chocolateStock > 0.0001) parts.add('Choc: ${QuantityFormatter.formatClean(item.chocolateStock)}');
    if (item.otherStock > 0.0001) parts.add('Other: ${QuantityFormatter.formatClean(item.otherStock)}');
    final breakdownText = parts.isEmpty ? 'Out of Stock' : parts.join(' • ');

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Code + Description + Unit
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  item.materialCode,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.unit.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Total Stock + Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Stock:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total ',
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    '${QuantityFormatter.formatClean(item.totalSystemStock)} ${item.unit.toUpperCase()}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              breakdownText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
