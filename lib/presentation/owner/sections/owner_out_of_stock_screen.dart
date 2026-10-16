import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';

/// Page Two — Out of Stock
/// Completely simplified, owner-friendly view displaying strictly:
/// - Code
/// - Description
/// - Qty (shown as 0)
/// Filtered by business-wide stock calculation (never falsely marks materials as out
/// of stock if available in another location).
class OwnerOutOfStockScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const OwnerOutOfStockScreen({
    super.key,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OwnerOutOfStockScreen> createState() => _OwnerOutOfStockScreenState();
}

class _OwnerOutOfStockScreenState extends ConsumerState<OwnerOutOfStockScreen> {
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

    // Use business-wide stock calculation ('ALL')
    final outOfStockAsync = ref.watch(ownerOutOfStockReportProvider((
      department: 'ALL',
      search: _searchQuery.isEmpty ? null : _searchQuery,
    )));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section Header & Simple Search Box
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.remove_shopping_cart_rounded, size: 18, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Out of Stock',
                              style: GoogleFonts.inter(
                                fontSize: isWide ? 17 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Materials with zero availability across the entire business',
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
                        tooltip: 'Refresh Out of Stock',
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                        onPressed: () => ref.invalidate(ownerOutOfStockReportProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Simple Search Box (identical to Live Stock)
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
              child: outOfStockAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFEF4444)),
                ),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load out of stock materials',
                    message: err.toString(),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(ownerOutOfStockReportProvider),
                  ),
                ),
                data: (materials) {
                  // Secondary search filter
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
                        icon: Icons.check_circle_outline_rounded,
                        title: _searchQuery.isEmpty
                            ? 'All materials are in stock'
                            : 'No out of stock materials match search',
                        message: _searchQuery.isEmpty
                            ? 'Every material currently has positive business inventory.'
                            : 'Try adjusting your search query.',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFEF4444),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: () async {
                      ref.invalidate(ownerOutOfStockReportProvider);
                    },
                    child: Column(
                      children: [
                        // Subtitle indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: const Color(0xFF0B0F19),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${filtered.length} out of stock materials',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEF4444),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Calculated Balance = 0',
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

                        // Table Header (Desktop / Tablet)
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
          const SizedBox(width: 12),
          Expanded(
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
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              'QTY',
              textAlign: TextAlign.right,
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

  Widget _buildDesktopRow(OwnerOutOfStockItem item) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
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
          const SizedBox(width: 12),

          // Description
          Expanded(
            child: Text(
              item.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Qty (strictly 0)
          SizedBox(
            width: 100,
            child: Text(
              '0 ${item.unit.toUpperCase()}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(OwnerOutOfStockItem item) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Code
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

          // Description
          Expanded(
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
          const SizedBox(width: 8),

          // Qty (strictly 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Text(
              '0 ${item.unit.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFCA5A5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
