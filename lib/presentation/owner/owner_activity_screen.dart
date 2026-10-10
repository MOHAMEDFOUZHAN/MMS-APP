import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/owner_dashboard_model.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../providers/owner_providers.dart';

class OwnerActivityScreen extends ConsumerStatefulWidget {
  const OwnerActivityScreen({super.key});

  @override
  ConsumerState<OwnerActivityScreen> createState() => _OwnerActivityScreenState();
}

class _OwnerActivityScreenState extends ConsumerState<OwnerActivityScreen> {
  String _search = '';
  String _selectedModule = 'All';

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(ownerAuditLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          'Executive Activity & Audit Trail',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Activity',
            onPressed: () => ref.invalidate(ownerAuditLogsProvider),
          ),
        ],
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(bottom: BorderSide(color: Color(0xFF1F2937))),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 440;
                  final searchField = SearchBarWidget(
                    hintText: 'Search user, action, or record...',
                    onChanged: (val) => setState(() => _search = val.toLowerCase()),
                  );
                  final dropdown = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedModule,
                        isExpanded: isNarrow,
                        dropdownColor: const Color(0xFF1F2937),
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9CA3AF)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Modules')),
                          DropdownMenuItem(value: 'materials', child: Text('Materials')),
                          DropdownMenuItem(value: 'invoices', child: Text('Invoices')),
                          DropdownMenuItem(value: 'storage', child: Text('Storage')),
                          DropdownMenuItem(value: 'dispatches', child: Text('Dispatches')),
                          DropdownMenuItem(value: 'transfers', child: Text('Transfers')),
                          DropdownMenuItem(value: 'stock_adjustments', child: Text('Adjustments')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedModule = val);
                        },
                      ),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        dropdown,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      dropdown,
                    ],
                  );
                },
              ),
            ),

            // Content Table / List
            Expanded(
              child: activityAsync.when(
                loading: () => const LoadingSkeletonList(count: 8),
                error: (e, _) => Center(
                  child: Text('Error loading activity: $e', style: const TextStyle(color: AppColors.danger)),
                ),
                data: (logs) {
                  final filtered = logs.where((l) {
                    if (_selectedModule != 'All' &&
                        !l.module.toLowerCase().contains(_selectedModule.toLowerCase())) {
                      return false;
                    }
                    if (_search.isNotEmpty) {
                      final u = l.userEmail.toLowerCase();
                      final op = l.operation.toLowerCase();
                      final mod = l.module.toLowerCase();
                      final rec = l.recordId.toLowerCase();
                      return u.contains(_search) ||
                          op.contains(_search) ||
                          mod.contains(_search) ||
                          rec.contains(_search);
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.history_rounded,
                      title: 'No Activity Found',
                      message: 'No audit trail logs match your filter criteria.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _buildAuditItemCard(item);
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

  Widget _buildAuditItemCard(OwnerActivityItem item) {
    Color opColor = const Color(0xFF6366F1);
    final op = item.operation.toUpperCase();
    if (op.contains('CREATE') || op.contains('INSERT')) {
      opColor = AppColors.success;
    } else if (op.contains('DELETE')) {
      opColor = AppColors.danger;
    } else if (op.contains('DISPATCH')) {
      opColor = const Color(0xFF06B6D4);
    } else if (op.contains('TRANSFER')) {
      opColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: opColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: opColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.operation,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: opColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 240;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.module.toUpperCase()} • Record: ${item.recordId}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.dateStr} • ${item.timeAmPm}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.module.toUpperCase()} • Record: ${item.recordId}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.dateStr} • ${item.timeAmPm}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 3),
                Text(
                  'User: ${item.userEmail}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                if (item.details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.details.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
