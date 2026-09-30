import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../providers/app_providers.dart';

class DepartmentConsumptionReport extends ConsumerStatefulWidget {
  const DepartmentConsumptionReport({super.key});

  @override
  ConsumerState<DepartmentConsumptionReport> createState() => _DepartmentConsumptionReportState();
}

class _DepartmentConsumptionReportState extends ConsumerState<DepartmentConsumptionReport> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String _selectedDept = 'All';

  @override
  Widget build(BuildContext context) {
    final params = {
      'from': _fromDate,
      'to': _toDate,
      'department': _selectedDept,
    };
    final reportAsync = ref.watch(departmentConsumptionReportProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Consumption'),
        actions: [
          reportAsync.maybeWhen(
            data: (rows) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Export & Print PDF',
                  onPressed: () => PdfExportService.printDepartmentConsumption(
                    rows,
                    _fromDate,
                    _toDate,
                    _selectedDept,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                  tooltip: 'Share PDF',
                  onPressed: () => PdfExportService.printDepartmentConsumption(
                    rows,
                    _fromDate,
                    _toDate,
                    _selectedDept,
                    share: true,
                  ),
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
            // Filter Controls
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
                              initialDate: _fromDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _fromDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'From Date'),
                            child: Text(QuantityFormatter.formatDate(_fromDate), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _toDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) setState(() => _toDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'To Date'),
                            child: Text(QuantityFormatter.formatDate(_toDate), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(labelText: 'Filter by Department'),
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Departments')),
                      ...FactoryConstants.departments.map((d) => DropdownMenuItem(value: d, child: Text(d))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedDept = val);
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: reportAsync.when(
                loading: () => const LoadingSkeletonList(count: 5),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No department transfers found',
                      message: 'No consumption logged for the selected period and department.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = rows[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(item.department, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                ),
                                Text(
                                  item.materialCode,
                                  style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Outward Issues', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      '${QuantityFormatter.format3Decimals(item.totalOutward)} ${item.unit}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('Returns In', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      '${QuantityFormatter.format3Decimals(item.totalReturn)} ${item.unit}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Net Consumed', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      '${QuantityFormatter.format3Decimals(item.netConsumed)} ${item.unit}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryLight),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
