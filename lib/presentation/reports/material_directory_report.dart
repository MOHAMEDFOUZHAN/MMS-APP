import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/quantity_formatter.dart';
import '../../core/services/pdf_export_service.dart';
import '../../core/theme/glass_widgets.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/app_providers.dart';

class MaterialDirectoryReport extends ConsumerStatefulWidget {
  const MaterialDirectoryReport({super.key});

  @override
  ConsumerState<MaterialDirectoryReport> createState() => _MaterialDirectoryReportState();
}

class _MaterialDirectoryReportState extends ConsumerState<MaterialDirectoryReport> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(materialDirectoryReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material Directory / Wall Chart'),
        actions: [
          reportAsync.maybeWhen(
            data: (rows) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.print_rounded),
                  tooltip: 'Export & Print PDF',
                  onPressed: () => PdfExportService.printMaterialDirectory(rows),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.accent),
                  tooltip: 'Share PDF',
                  onPressed: () => PdfExportService.printMaterialDirectory(rows, share: true),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(
                hintText: 'Search code, description, or shelf location...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: reportAsync.when(
                loading: () => const LoadingSkeletonList(count: 6),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (rows) {
                  final filtered = rows.where((r) {
                    if (_search.isEmpty) return true;
                    return r.materialCode.toLowerCase().contains(_search) ||
                        r.description.toLowerCase().contains(_search) ||
                        r.shelfLocation.toLowerCase().contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      title: 'No materials found',
                      message: 'No directory items matching your criteria.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primaryLight),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.materialCode,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryLight),
                                      ),
                                      const SizedBox(width: 6),
                                      Text('• ${item.category}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 11, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Shelf: ${item.shelfLocation}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Total Stock', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text(
                                  QuantityFormatter.formatDualUnit(item.currentStock, item.unit),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
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
