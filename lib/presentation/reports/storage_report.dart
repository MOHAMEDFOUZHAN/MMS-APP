import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/batch_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';

class StorageReport extends ConsumerStatefulWidget {
  const StorageReport({super.key});

  @override
  ConsumerState<StorageReport> createState() => _StorageReportState();
}

class _StorageReportState extends ConsumerState<StorageReport> {
  String _selectedDept = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final batchesRepo = ref.watch(batchesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Storage Register'),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Filter Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.glassSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDept,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                          items: [
                            const DropdownMenuItem(value: 'All', child: Text('All Storage Locations')),
                            ...FactoryConstants.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDept = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBarWidget(
                hintText: 'Search batch no, material or description...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),

            // Batches List
            Expanded(
              child: FutureBuilder<List<BatchModel>>(
                future: batchesRepo.fetchActiveBatches(search: _search.isNotEmpty ? _search : null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingSkeletonList(count: 6);
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)),
                    );
                  }

                  var list = snapshot.data ?? [];
                  if (_selectedDept != 'All') {
                    list = list.where((b) => b.department.toLowerCase().contains(_selectedDept.toLowerCase())).toList();
                  }

                  if (list.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No Active Batches',
                      message: 'No storage batches currently hold available inventory.',
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${list.length} Batches with Available Stock',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                            ),
                            TextButton.icon(
                              onPressed: () => PdfExportService.printStorageReport(list),
                              icon: const Icon(Icons.print_rounded, size: 16, color: AppColors.primaryLight),
                              label: const Text('Export PDF', style: TextStyle(fontSize: 12, color: AppColors.primaryLight)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 768) {
                              return _buildTabletTable(list);
                            }
                            return _buildMobileCards(list);
                          },
                        ),
                      ),
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

  Widget _buildMobileCards(List<BatchModel> list) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = list[i];
        final ratio = b.receivedQuantity > 0 ? (b.availableQuantity / b.receivedQuantity).clamp(0.0, 1.0) : 0.0;

        return GlassCard(
          padding: const EdgeInsets.all(14),
          accentColor: AppColors.primaryLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch #${b.batchNo}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        Text(
                          '${b.materialCode} • ${b.description}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      b.department,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Available', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${QuantityFormatter.format3Decimals(b.availableQuantity)} ${b.uom}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Received', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${QuantityFormatter.format3Decimals(b.receivedQuantity)} ${b.uom}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Received Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        b.receivedDate != null ? QuantityFormatter.formatDate(b.receivedDate!) : '-',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabletTable(List<BatchModel> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(2.0),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(0.8),
            7: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1.5)),
              ),
              children: [
                _tableHeader('Batch No'),
                _tableHeader('Code'),
                _tableHeader('Description'),
                _tableHeader('Department'),
                _tableHeader('Received'),
                _tableHeader('Available'),
                _tableHeader('UOM'),
                _tableHeader('Date'),
              ],
            ),
            ...list.map((b) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
                  ),
                  children: [
                    _tableCell(b.batchNo, isBold: true),
                    _tableCell(b.materialCode),
                    _tableCell(b.description),
                    _tableCell(b.department),
                    _tableCell(QuantityFormatter.format3Decimals(b.receivedQuantity)),
                    _tableCell(QuantityFormatter.format3Decimals(b.availableQuantity), color: AppColors.success),
                    _tableCell(b.uom),
                    _tableCell(b.receivedDate != null ? QuantityFormatter.formatDate(b.receivedDate!) : '-'),
                  ],
                )),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textMuted)),
    );
  }

  Widget _tableCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}
