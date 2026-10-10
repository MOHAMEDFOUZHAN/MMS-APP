import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/expiry_helper.dart';
import '../../data/models/inventory_settings_model.dart';
import '../../data/models/material_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';
import '../providers/inventory_settings_provider.dart';

class ExpiringReport extends ConsumerStatefulWidget {
  const ExpiringReport({super.key});

  @override
  ConsumerState<ExpiringReport> createState() => _ExpiringReportState();
}

class _ExpiringReportState extends ConsumerState<ExpiringReport> {
  String _selectedCategory = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final materialsRepo = ref.watch(materialsRepositoryProvider);
    final settings = ref.watch(inventorySettingsProvider).value ?? const InventorySettingsModel();
    final alertDays = settings.invoiceMaterialExpiryAlertDays;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Items Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
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
                hintText: 'Search material, lot, or code...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),

            // Content
            Expanded(
              child: FutureBuilder<List<MaterialModel>>(
                future: materialsRepo.fetchMaterials(
                  status: 'expiring',
                  category: _selectedCategory != 'All' ? _selectedCategory : null,
                  search: _search.isNotEmpty ? _search : null,
                  invoiceMaterialExpiryAlertDays: alertDays,
                  limit: 200,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingSkeletonList(count: 6);
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load expiring report',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 16),
                            GlassButton(
                              text: 'Retry',
                              icon: Icons.refresh_rounded,
                              color: AppColors.primary,
                              onPressed: () => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final list = snapshot.data ?? [];

                  if (list.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No Expiring Items',
                      message: 'No materials are approaching their shelf-life expiry within $alertDays days.',
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
                              '${list.length} Lots Expiring Soon / Expired (Threshold: ${alertDays}d)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
                            ),
                            TextButton.icon(
                              onPressed: () => PdfExportService.printExpiringReport(list),
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
                              return _buildTabletTable(list, alertDays);
                            }
                            return _buildMobileCards(list, alertDays);
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

  Widget _buildMobileCards(List<MaterialModel> list, int alertDays) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final item = list[i];
        final expiryStatus = ExpiryHelper.calculate(
          expiryDate: item.expiryDate,
          alertDaysThreshold: alertDays,
        );

        return GlassCard(
          padding: const EdgeInsets.all(14),
          accentColor: expiryStatus.accentColor,
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
                  ExpiryHelper.buildBadge(expiryStatus),
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
                      const Text('Expiry Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        item.expiryDate != null ? QuantityFormatter.formatDate(item.expiryDate!) : '-',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: expiryStatus.accentColor),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Stock on Hand', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      Text(
                        '${QuantityFormatter.format3Decimals(item.quantity)} ${item.unit}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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

  Widget _buildTabletTable(List<MaterialModel> list, int alertDays) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(0.8),
            5: FlexColumnWidth(1.2),
            6: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1.5)),
              ),
              children: [
                _tableHeader('Code'),
                _tableHeader('Description'),
                _tableHeader('Lot No'),
                _tableHeader('Stock'),
                _tableHeader('Unit'),
                _tableHeader('Expiry Date'),
                _tableHeader('Status'),
              ],
            ),
            ...list.map((m) {
              final expiryStatus = ExpiryHelper.calculate(
                expiryDate: m.expiryDate,
                alertDaysThreshold: alertDays,
              );

              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
                ),
                children: [
                  _tableCell(m.materialCode, isBold: true),
                  _tableCell(m.description),
                  _tableCell(m.lotNo.isNotEmpty ? m.lotNo : '-'),
                  _tableCell(QuantityFormatter.format3Decimals(m.quantity)),
                  _tableCell(m.unit),
                  _tableCell(m.expiryDate != null ? QuantityFormatter.formatDate(m.expiryDate!) : '-'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ExpiryHelper.buildBadge(expiryStatus),
                  ),
                ],
              );
            }),
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
