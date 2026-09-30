import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';

class OutOfStockReport extends ConsumerStatefulWidget {
  const OutOfStockReport({super.key});

  @override
  ConsumerState<OutOfStockReport> createState() => _OutOfStockReportState();
}

class _OutOfStockReportState extends ConsumerState<OutOfStockReport> {
  String _selectedCategory = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final materialsRepo = ref.watch(materialsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Out of Stock Report'),
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
                    child: categoriesAsync.maybeWhen(
                      data: (cats) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.glassSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: AppColors.surface,
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                            items: [
                              const DropdownMenuItem(value: 'All', child: Text('All Categories')),
                              ...cats.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCategory = val);
                            },
                          ),
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBarWidget(
                hintText: 'Search material or code...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<MaterialModel>>(
                future: materialsRepo.fetchMaterials(
                  status: 'out_of_stock',
                  category: _selectedCategory != 'All' ? _selectedCategory : null,
                  search: _search.isNotEmpty ? _search : null,
                  limit: 200,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingSkeletonList(count: 6);
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)),
                    );
                  }

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No Depleted Stock',
                      message: 'All inventory items currently have stock available.',
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
                              '${list.length} Items Completely Depleted',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger),
                            ),
                            TextButton.icon(
                              onPressed: () => PdfExportService.printOutOfStockReport(list),
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

  Widget _buildMobileCards(List<MaterialModel> list) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = list[i];

        return GlassCard(
          padding: const EdgeInsets.all(14),
          accentColor: AppColors.danger,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.materialCode,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '0.000 Stock',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lot No', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        item.lotNo.isNotEmpty ? item.lotNo : '-',
                        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Reorder Level', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${QuantityFormatter.format3Decimals(item.reorderLevel)} ${item.unit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.warning),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Category', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        item.category,
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryLight),
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

  Widget _buildTabletTable(List<MaterialModel> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(0.8),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1.5)),
              ),
              children: [
                _tableHeader('Code'),
                _tableHeader('Description'),
                _tableHeader('Category'),
                _tableHeader('Current Stock'),
                _tableHeader('Reorder Level'),
                _tableHeader('Lot No'),
                _tableHeader('Unit'),
              ],
            ),
            ...list.map((m) => TableRow(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
                  ),
                  children: [
                    _tableCell(m.materialCode, isBold: true),
                    _tableCell(m.description),
                    _tableCell(m.category),
                    _tableCell('0.000', color: AppColors.danger),
                    _tableCell(QuantityFormatter.format3Decimals(m.reorderLevel)),
                    _tableCell(m.lotNo.isNotEmpty ? m.lotNo : '-'),
                    _tableCell(m.unit),
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
