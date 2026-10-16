import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../core/theme/glass_widgets.dart';
import '../../../data/models/chocolate_ocr_ledger_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/global_search_filter_bar.dart';
import '../../providers/chocolate_ocr_providers.dart';

class ChocolateDepartmentReportScreen extends ConsumerStatefulWidget {
  const ChocolateDepartmentReportScreen({super.key});

  @override
  ConsumerState<ChocolateDepartmentReportScreen> createState() => _ChocolateDepartmentReportScreenState();
}

class _ChocolateDepartmentReportScreenState extends ConsumerState<ChocolateDepartmentReportScreen> {
  String _search = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(chocolateOcrLedgerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.document_scanner_rounded, color: Color(0xFFF59E0B), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Chocolate Department Executive Report',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // KPI Summary Header
            ledgerAsync.maybeWhen(
              data: (list) {
                double totalWeight = 0;
                int confirmedCount = 0;
                for (final item in list) {
                  totalWeight += item.quantity;
                  if (item.status.toUpperCase() == 'CONFIRMED') confirmedCount++;
                }
                return _buildKpiRow(list.length, confirmedCount, totalWeight);
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Search Bar
            GlobalSearchFilterBar(
              hintText: 'Search by Description, Document, or Operator...',
              initialSearch: _search,
              initialFromDate: _fromDate,
              initialToDate: _toDate,
              onSearchChanged: (val) => setState(() => _search = val),
              onApply: (search, from, to) => setState(() {
                _search = search;
                _fromDate = from;
                _toDate = to;
              }),
              onClear: () => setState(() {
                _search = '';
                _fromDate = null;
                _toDate = null;
              }),
            ),

            // Ledger List
            Expanded(
              child: ledgerAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (entries) {
                  final filtered = entries.where((e) {
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      final desc = e.description.toLowerCase();
                      final doc = (e.documentName ?? '').toLowerCase();
                      final user = (e.createdBy ?? '').toLowerCase();
                      if (!desc.contains(q) && !doc.contains(q) && !user.contains(q)) return false;
                    }
                    if (_fromDate != null && e.createdAt != null && e.createdAt!.isBefore(_fromDate!)) return false;
                    if (_toDate != null && e.createdAt != null && e.createdAt!.isAfter(_toDate!.add(const Duration(days: 1)))) return false;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.document_scanner_outlined,
                      title: 'No Chocolate Ledger Records',
                      message: 'Weighing scale scans and production entries will appear here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _buildChocolateCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(int totalCount, int confirmedCount, double totalWeight) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 650;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _kpiBox('Total Scale Records', '$totalCount entries', const Color(0xFFD97706), isWide ? (constraints.maxWidth - 16) / 3 : constraints.maxWidth),
              _kpiBox('Confirmed Entries', '$confirmedCount verified', const Color(0xFF10B981), isWide ? (constraints.maxWidth - 16) / 3 : (constraints.maxWidth - 8) / 2),
              _kpiBox('Total Net Weight', '${QuantityFormatter.formatClean(totalWeight)} kg', const Color(0xFFF59E0B), isWide ? (constraints.maxWidth - 16) / 3 : (constraints.maxWidth - 8) / 2),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiBox(String title, String value, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildChocolateCard(ChocolateOcrLedgerModel item) {
    final dateStr = item.createdAt != null ? AppDateFormatter.format(item.createdAt!) : 'N/A';
    final timeStr = item.createdAt != null ? DateFormat('hh:mm a').format(item.createdAt!.toLocal()) : '';
    final isConfirmed = item.status.toUpperCase() == 'CONFIRMED';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConfirmed ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item.description, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isConfirmed ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isConfirmed ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('$dateStr at $timeStr', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppColors.textMuted)),
              if (item.documentName != null && item.documentName!.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.description_outlined, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(item.documentName!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ],
          ),
          const Divider(height: 16, color: Color(0xFF1F2937)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Raw OCR: ${QuantityFormatter.formatClean(item.rawOcrQuantity)} ${item.unit}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                'Confirmed: ${QuantityFormatter.formatClean(item.quantity)} ${item.unit}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
