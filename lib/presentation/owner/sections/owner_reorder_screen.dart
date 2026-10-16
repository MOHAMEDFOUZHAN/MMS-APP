import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/owner_providers.dart';

/// Page Three — Reorder Level
/// Shows materials whose current stock has reached or fallen below their configured reorder level.
/// Columns displayed: Code, Description, Current Qty, Reorder Level, and an Edit option.
/// Includes support for configuring materials that have no set reorder level.
class OwnerReorderScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;

  const OwnerReorderScreen({
    super.key,
    this.onBackToDashboard,
  });

  @override
  ConsumerState<OwnerReorderScreen> createState() => _OwnerReorderScreenState();
}

enum ReorderFilterMode {
  belowReorder, // reorder_level > 0 AND current_stock <= reorder_level
  needsConfig, // reorder_level <= 0 or not configured
  allItems, // all materials
}

class _OwnerReorderScreenState extends ConsumerState<OwnerReorderScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ReorderFilterMode _filterMode = ReorderFilterMode.belowReorder;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditReorderDialog(BuildContext context, OwnerReorderItem item) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: item.reorderLevel > 0 ? QuantityFormatter.formatClean(item.reorderLevel) : '',
    );
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Reorder Level',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Material Code & Description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  item.materialCode,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.unit.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.description,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Current Stock (Read-only)
                            Row(
                              children: [
                                Text(
                                  'Current Stock: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                                Text(
                                  '${QuantityFormatter.formatClean(item.currentStock)} ${item.unit.toUpperCase()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.currentStock > 0.0001
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(Read-only)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Reorder Level Input Field
                      Text(
                        'Reorder Level Threshold (${item.unit.toUpperCase()})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter reorder quantity (e.g. 50)',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF334155)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a reorder level threshold.';
                          }
                          final numVal = double.tryParse(val.trim());
                          if (numVal == null) {
                            return 'Enter a valid numeric value.';
                          }
                          if (numVal < 0) {
                            return 'Reorder level cannot be negative.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Note: Editing the reorder level permanently updates the replenishment trigger. Stock quantity is strictly never modified.',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newLevel = double.parse(controller.text.trim());

                          setDialogState(() => isSaving = true);

                          try {
                            await ref
                                .read(ownerRepositoryProvider)
                                .updateMaterialReorderLevel(item.materialCode, newLevel);

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            // Refresh provider automatically
                            ref.invalidate(ownerReorderReportProvider);
                            ref.invalidate(ownerLiveStockProvider);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Reorder level for ${item.description} updated to ${QuantityFormatter.formatClean(newLevel)} ${item.unit.toUpperCase()}',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to save reorder level: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : Text(
                          'Save Reorder Level',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;

    final reorderAsync = ref.watch(ownerReorderReportProvider((
      department: 'ALL',
      search: _searchQuery.isEmpty ? null : _searchQuery,
      status: 'ALL',
    )));

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section Header
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
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.low_priority_rounded, size: 18, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reorder Level',
                              style: GoogleFonts.inter(
                                fontSize: isWide ? 17 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Materials that reached or fallen below minimum threshold',
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
                        tooltip: 'Refresh Reorder Report',
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                        onPressed: () => ref.invalidate(ownerReorderReportProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Simple Search Box
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
                  const SizedBox(height: 10),

                  // Simple Filter Pills: At or Below Reorder (Default), Needs Configuration, All Items
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'At / Below Reorder',
                          mode: ReorderFilterMode.belowReorder,
                          activeColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'Needs Configuration',
                          mode: ReorderFilterMode.needsConfig,
                          activeColor: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: 'All Materials',
                          mode: ReorderFilterMode.allItems,
                          activeColor: const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content List / Table
            Expanded(
              child: reorderAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                ),
                error: (err, _) => Center(
                  child: EmptyStateWidget(
                    icon: Icons.error_outline_rounded,
                    title: 'Failed to load reorder report',
                    message: err.toString(),
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(ownerReorderReportProvider),
                  ),
                ),
                data: (materials) {
                  // Filter according to ReorderFilterMode and search query
                  final filtered = materials.where((m) {
                    // Search query check
                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      final matches = m.materialCode.toLowerCase().contains(q) ||
                          m.description.toLowerCase().contains(q);
                      if (!matches) return false;
                    }

                    switch (_filterMode) {
                      case ReorderFilterMode.belowReorder:
                        // Stock has reached or fallen below configured reorder level
                        return m.reorderLevel > 0 && m.currentStock <= m.reorderLevel;
                      case ReorderFilterMode.needsConfig:
                        // No configured reorder level
                        return m.reorderLevel <= 0.0001;
                      case ReorderFilterMode.allItems:
                        return true;
                    }
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: EmptyStateWidget(
                        icon: Icons.check_circle_outline_rounded,
                        title: _filterMode == ReorderFilterMode.belowReorder
                            ? 'No materials currently at or below reorder level'
                            : (_filterMode == ReorderFilterMode.needsConfig
                                ? 'All materials have configured reorder levels'
                                : 'No materials found'),
                        message: _searchQuery.isNotEmpty
                            ? 'No items match your search.'
                            : 'All stock levels are above configured minimum thresholds.',
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: const Color(0xFFF59E0B),
                    backgroundColor: const Color(0xFF1E293B),
                    onRefresh: () async {
                      ref.invalidate(ownerReorderReportProvider);
                    },
                    child: Column(
                      children: [
                        // Subtitle status line
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: const Color(0xFF0B0F19),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${filtered.length} materials listed',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Tap Edit to set threshold',
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

                        // Table Header (Desktop / Tablet view)
                        if (isWide) _buildTableHeader(),

                        // List of rows
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

  Widget _buildFilterChip({
    required String label,
    required ReorderFilterMode mode,
    required Color activeColor,
  }) {
    final isSelected = _filterMode == mode;
    return InkWell(
      onTap: () => setState(() => _filterMode = mode),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
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
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
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
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              'CURRENT QTY',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              'REORDER LEVEL',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 75), // Edit action column
        ],
      ),
    );
  }

  Widget _buildDesktopRow(OwnerReorderItem item) {
    final hasReorderLevel = item.reorderLevel > 0;
    final isAtOrBelow = hasReorderLevel && item.currentStock <= item.reorderLevel;

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
          const SizedBox(width: 10),

          // Description
          Expanded(
            flex: 4,
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
          const SizedBox(width: 10),

          // Current Qty
          Expanded(
            flex: 2,
            child: Text(
              '${QuantityFormatter.formatClean(item.currentStock)} ${item.unit.toUpperCase()}',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isAtOrBelow
                    ? const Color(0xFFEF4444)
                    : (item.currentStock > 0.0001 ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Reorder Level
          Expanded(
            flex: 2,
            child: Text(
              hasReorderLevel
                  ? '${QuantityFormatter.formatClean(item.reorderLevel)} ${item.unit.toUpperCase()}'
                  : 'Not Set',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: hasReorderLevel ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                fontStyle: hasReorderLevel ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Edit Option Button
          SizedBox(
            width: 75,
            child: Center(
              child: InkWell(
                onTap: () => _openEditReorderDialog(context, item),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 11, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(OwnerReorderItem item) {
    final hasReorderLevel = item.reorderLevel > 0;
    final isAtOrBelow = hasReorderLevel && item.currentStock <= item.reorderLevel;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Code + Description + Edit Button
          Row(
            children: [
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
              Expanded(
                child: Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openEditReorderDialog(context, item),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 11, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Current Qty vs Reorder Level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current: ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    Flexible(
                      child: Text(
                        '${QuantityFormatter.formatClean(item.currentStock)} ${item.unit.toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isAtOrBelow ? const Color(0xFFEF4444) : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Reorder: ',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                    Flexible(
                      child: Text(
                        hasReorderLevel
                            ? '${QuantityFormatter.formatClean(item.reorderLevel)} ${item.unit.toUpperCase()}'
                            : 'Not Set',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasReorderLevel ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
