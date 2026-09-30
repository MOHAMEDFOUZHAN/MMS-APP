import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/report_models.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';

class MurReport extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const MurReport({super.key, this.isEmbedded = false});

  @override
  ConsumerState<MurReport> createState() => _MurReportState();
}

class _MurReportState extends ConsumerState<MurReport> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _selectedCategory = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final params = {
      'start': _startDate,
      'end': _endDate,
      'category': _selectedCategory,
    };
    final murAsync = ref.watch(murReportProvider(params));

    return Scaffold(
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('Material Utilization (MUR)'),
              actions: [
                murAsync.maybeWhen(
                  data: (rows) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print_rounded),
                        tooltip: 'Export & Print PDF',
                        onPressed: () => PdfExportService.printMurReport(rows, _startDate, _endDate),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                        tooltip: 'Share PDF',
                        onPressed: () => PdfExportService.printMurReport(rows, _startDate, _endDate, share: true),
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
            // Period & Category Filters Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _startDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.glassSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('From Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      QuantityFormatter.formatDate(_startDate),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _endDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.glassSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded, size: 14, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('To Date', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      QuantityFormatter.formatDate(_endDate),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Category Filter dropdown
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
                      if (widget.isEmbedded) ...[
                        const SizedBox(width: 8),
                        murAsync.maybeWhen(
                          data: (rows) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassButton(
                                text: 'Export PDF',
                                icon: Icons.print_rounded,
                                height: 42,
                                color: const Color(0xFF8B5CF6),
                                onPressed: () => PdfExportService.printMurReport(rows, _startDate, _endDate),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                                tooltip: 'Share MUR Report',
                                onPressed: () => PdfExportService.printMurReport(rows, _startDate, _endDate, share: true),
                              ),
                            ],
                          ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBarWidget(
                hintText: 'Search code or description...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),

            // MUR Rows
            Expanded(
              child: murAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (e, _) => Center(
                  child: Text('Error loading MUR: $e', style: const TextStyle(color: AppColors.danger)),
                ),
                data: (rows) {
                  final filtered = rows.where((r) {
                    if (_search.isEmpty) return true;
                    return r.materialCode.toLowerCase().contains(_search) ||
                        r.description.toLowerCase().contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No utilization records',
                      message: 'No material movements found for the selected period.',
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth >= 768;

                      if (isTablet) {
                        return _buildTabletTable(filtered);
                      }
                      return _buildMobileCards(filtered);
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

  Widget _buildMobileCards(List<MurReportRow> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = rows[i];
        final utilColor = r.utilizationPercent > 80
            ? AppColors.success
            : r.utilizationPercent > 40
                ? AppColors.primaryLight
                : AppColors.warning;

        return GlassCard(
          padding: const EdgeInsets.all(14),
          accentColor: utilColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.materialCode,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: utilColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: utilColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${r.utilizationPercent.toStringAsFixed(1)}% Utilized',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: utilColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.description,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (r.utilizationPercent / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(utilColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              // Ledger Metrics Matrix
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metricBox('Opening', r.opening, r.unit),
                  _metricBox('Purchased', r.purchased, r.unit, color: AppColors.accent),
                  _metricBox('Used', r.used, r.unit, color: AppColors.secondary),
                  _metricBox('Closing', r.closing, r.unit, color: AppColors.primaryLight),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricBox(String label, double val, String unit, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          QuantityFormatter.format3Decimals(val),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(unit, style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildTabletTable(List<MurReportRow> rows) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(0.8),
            7: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 1.5)),
              ),
              children: [
                _tableHeader('Code'),
                _tableHeader('Description'),
                _tableHeader('Opening'),
                _tableHeader('Purchased'),
                _tableHeader('Used'),
                _tableHeader('Closing'),
                _tableHeader('Unit'),
                _tableHeader('Util %'),
              ],
            ),
            ...rows.map((r) {
              final utilColor = r.utilizationPercent > 80
                  ? AppColors.success
                  : r.utilizationPercent > 40
                      ? AppColors.primaryLight
                      : AppColors.warning;
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
                ),
                children: [
                  _tableCell(r.materialCode, isBold: true),
                  _tableCell(r.description),
                  _tableCell(QuantityFormatter.format3Decimals(r.opening)),
                  _tableCell(QuantityFormatter.format3Decimals(r.purchased), color: AppColors.accent),
                  _tableCell(QuantityFormatter.format3Decimals(r.used), color: AppColors.secondary),
                  _tableCell(QuantityFormatter.format3Decimals(r.closing), color: AppColors.primaryLight),
                  _tableCell(r.unit),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${r.utilizationPercent.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: utilColor, fontSize: 11),
                    ),
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
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textMuted),
      ),
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
