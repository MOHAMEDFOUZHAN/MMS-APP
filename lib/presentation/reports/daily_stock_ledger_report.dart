import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/app_providers.dart';

class DailyStockLedgerReport extends ConsumerStatefulWidget {
  const DailyStockLedgerReport({super.key});

  @override
  ConsumerState<DailyStockLedgerReport> createState() => _DailyStockLedgerReportState();
}

class _DailyStockLedgerReportState extends ConsumerState<DailyStockLedgerReport> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(dailyLedgerReportProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Stock Ledger'),
        actions: [
          ledgerAsync.maybeWhen(
            data: (rows) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Export & Print PDF',
                  onPressed: () => PdfExportService.printDailyLedger(rows, _selectedDate),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                  tooltip: 'Share Daily Ledger PDF',
                  onPressed: () => PdfExportService.printDailyLedger(rows, _selectedDate, share: true),
                ),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Date Picker Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      Text(
                        'Ledger Date: ${QuantityFormatter.formatDate(_selectedDate)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                    label: const Text('Change Date'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(40, 36),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: ledgerAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No transactions for this date',
                      message: 'Choose another date to view opening, flows, and closing balances.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  row.materialCode,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                                ),
                                Text(
                                  'UOM: ${row.unit}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            Text(
                              row.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMetric('Opening', row.openingStock, row.unit, AppColors.textSecondary),
                                _buildMetric('Inward', row.purchased, row.unit, AppColors.success),
                                _buildMetric('Outward', row.transferOut, row.unit, AppColors.warning),
                                _buildMetric('Returns', row.returnIn, row.unit, AppColors.accent),
                                _buildMetric('Dispatched', row.dispatched, row.unit, AppColors.secondary),
                                _buildMetric('Closing', row.closingStock, row.unit, AppColors.primaryLight, isBold: true),
                              ],
                            ),
                          ],
                        ),
                      );
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

  Widget _buildMetric(String label, double val, String unit, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          QuantityFormatter.formatClean(val),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
