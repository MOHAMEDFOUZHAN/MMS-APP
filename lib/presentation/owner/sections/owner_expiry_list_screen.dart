import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/owner_reporting_models.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../providers/inventory_settings_provider.dart';
import '../../providers/owner_providers.dart';

/// Page Four — Expiry List & Management Notification Settings
/// Displays materials/products that have expiry dates recorded in the system.
/// Exactly 5 Columns: Code, Description, Expiry Date, Qty, Days Left.
class OwnerExpiryListScreen extends ConsumerStatefulWidget {
  const OwnerExpiryListScreen({super.key});

  @override
  ConsumerState<OwnerExpiryListScreen> createState() => _OwnerExpiryListScreenState();
}

class _OwnerExpiryListScreenState extends ConsumerState<OwnerExpiryListScreen> {
  final _searchController = TextEditingController();
  final _daysController = TextEditingController();
  String _searchQuery = '';
  bool _filterByAlertWindow = true;
  bool _isSavingSetting = false;
  final Set<String> _dispatchedNotificationKeys = {};

  @override
  void initState() {
    super.initState();
    final currentAlertDays = ref.read(inventorySettingsProvider).valueOrNull?.invoiceMaterialExpiryAlertDays ?? 30;
    _daysController.text = currentAlertDays.toString();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveSetting(int newDays) async {
    if (newDays < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid non-negative whole number of days.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingSetting = true);
    try {
      await ref.read(inventorySettingsProvider.notifier).saveSettings(
        invoiceMaterialExpiryAlertDays: newDays,
        storageProductExpiryAlertDays: newDays,
      );
      if (mounted) {
        _daysController.text = newDays.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Notification window saved: $newDays days before expiry.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSetting = false);
      }
    }
  }

  void _triggerExpiryNotificationsIfNeeded(List<OwnerExpiryListItem> items, int alertDays) {
    for (final item in items) {
      if (item.daysLeft <= alertDays) {
        final notifStatus = item.isExpired || item.daysLeft <= 0 ? 'EXPIRED' : 'ALERT_${item.daysLeft}';
        final dedupeKey = '${item.materialCode}:${item.batchOrLot ?? ""}:$notifStatus';

        if (!_dispatchedNotificationKeys.contains(dedupeKey)) {
          _dispatchedNotificationKeys.add(dedupeKey);
          try {
            NotificationService.instance.showExpiryAlert(
              batchNumber: item.batchOrLot ?? item.materialCode,
              materialName: '${item.materialCode} - ${item.description}',
              daysLeft: item.daysLeft,
            );
          } catch (e) {
            debugPrint('Notification alert skipped in test/mock environment: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 640;

    final settings = ref.watch(inventorySettingsProvider).valueOrNull;
    final alertDays = settings?.invoiceMaterialExpiryAlertDays ?? 30;

    // Synchronize controller text if not currently focused/editing
    if (!_isSavingSetting && _daysController.text != alertDays.toString() && !FocusScope.of(context).hasFocus) {
      _daysController.text = alertDays.toString();
    }

    final queryArg = (
      daysWindow: _filterByAlertWindow ? alertDays : null,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    final expiryListAsync = ref.watch(ownerExpiryReportProvider(queryArg));

    // Listen to data changes to safely dispatch notifications once
    ref.listen<AsyncValue<List<OwnerExpiryListItem>>>(
      ownerExpiryReportProvider(queryArg),
      (prev, next) {
        final items = next.valueOrNull;
        if (items != null && items.isNotEmpty) {
          _triggerExpiryNotificationsIfNeeded(items, alertDays);
        }
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
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
                          color: const Color(0xFFF97316).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.event_busy_rounded, size: 18, color: Color(0xFFF97316)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expiry List',
                              style: GoogleFonts.inter(
                                fontSize: isWide ? 17 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Materials & products with tracked expiry dates',
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
                        tooltip: 'Refresh Expiry List',
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                        onPressed: () {
                          ref.invalidate(inventorySettingsProvider);
                          ref.invalidate(ownerExpiryReportProvider);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Editable Expiry Notification Setting Card
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
                            const Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Expiry Notification Setting',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Show expiry notification',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCBD5E1)),
                            ),
                            SizedBox(
                              width: 70,
                              height: 34,
                              child: TextField(
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFF475569)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              'days before expiry.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCBD5E1)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _isSavingSetting
                                  ? null
                                  : () {
                                      final val = int.tryParse(_daysController.text.trim());
                                      if (val == null || val < 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter a valid whole number (e.g. 7, 15, 30, 60).'),
                                            backgroundColor: AppColors.danger,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      _handleSaveSetting(val);
                                    },
                              child: _isSavingSetting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick Presets
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Quick select: ',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                            ...[7, 15, 30, 60].map((d) {
                              final isSelected = alertDays == d;
                              return InkWell(
                                onTap: () {
                                  _daysController.text = d.toString();
                                  _handleSaveSetting(d);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF475569),
                                    ),
                                  ),
                                  child: Text(
                                    '$d days',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Simple Search Box & Filter Toggle
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search by code or description...',
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter toggle chip
                      InkWell(
                        onTap: () => setState(() => _filterByAlertWindow = !_filterByAlertWindow),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _filterByAlertWindow
                                ? const Color(0xFFF97316).withValues(alpha: 0.18)
                                : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _filterByAlertWindow
                                  ? const Color(0xFFF97316).withValues(alpha: 0.6)
                                  : const Color(0xFF334155),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _filterByAlertWindow ? Icons.filter_alt_rounded : Icons.filter_alt_off_rounded,
                                size: 16,
                                color: _filterByAlertWindow ? const Color(0xFFF97316) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _filterByAlertWindow ? 'Window (≤$alertDays d)' : 'Show All',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _filterByAlertWindow ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: expiryListAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading expiry list',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(ownerExpiryReportProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: EmptyStateWidget(
                        icon: Icons.event_available_rounded,
                        title: _searchQuery.isNotEmpty
                            ? 'No Expiries Matching "$_searchQuery"'
                            : _filterByAlertWindow
                                ? 'No Items Expiring Within $alertDays Days'
                                : 'No Tracked Expiry Dates Found',
                        message: _filterByAlertWindow
                            ? 'All recorded materials are within safe shelf life or tap "Show All" to inspect full inventory dates.'
                            : 'No materials or batches currently have expiry dates recorded in the system.',
                        actionLabel: _filterByAlertWindow ? 'Show All Expiries' : null,
                        onAction: _filterByAlertWindow
                            ? () => setState(() => _filterByAlertWindow = false)
                            : null,
                      ),
                    );
                  }

                  return isWide
                      ? _buildDesktopTable(items)
                      : _buildMobileList(items);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wide Screen Table: Strictly displays Code, Description, Expiry Date, Qty, Days Left
  Widget _buildDesktopTable(List<OwnerExpiryListItem> items) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  'Code',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Description',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  'Expiry Date',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 130,
                child: Text(
                  'Days Left',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E293B)),
            itemBuilder: (context, index) {
              final item = items[index];
              final isExpired = item.isExpired || item.daysLeft <= 0;

              return Container(
                color: isExpired
                    ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                    : (index % 2 == 0 ? const Color(0xFF0F172A) : const Color(0xFF0B0F19)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Code
                    SizedBox(
                      width: 110,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.materialCode,
                            style: GoogleFonts.robotoMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isExpired ? const Color(0xFFF87171) : const Color(0xFFF59E0B),
                            ),
                          ),
                          if (item.batchOrLot != null && item.batchOrLot!.isNotEmpty)
                            Text(
                              item.batchOrLot!,
                              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),

                    // Description
                    Expanded(
                      flex: 4,
                      child: Text(
                        item.description,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    // Expiry Date
                    SizedBox(
                      width: 130,
                      child: Text(
                        item.formattedExpiryDate,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpired ? const Color(0xFFF87171) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),

                    // Qty
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.formattedQuantity,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Days Left
                    SizedBox(
                      width: 130,
                      child: Center(
                        child: _buildDaysLeftBadge(item),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Mobile List: strictly displays Code, Description, Expiry Date, Qty, Days Left
  Widget _buildMobileList(List<OwnerExpiryListItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isExpired = item.isExpired || item.daysLeft <= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isExpired ? const Color(0xFF1E1418) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpired
                  ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                  : const Color(0xFF1E293B),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Code & Days Left Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        item.materialCode,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? const Color(0xFFF87171) : const Color(0xFFF59E0B),
                        ),
                      ),
                      if (item.batchOrLot != null && item.batchOrLot!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.batchOrLot!,
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildDaysLeftBadge(item),
                ],
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                item.description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Bottom Row: Expiry Date & Qty
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note_rounded, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'Expiry: ${item.formattedExpiryDate}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isExpired ? const Color(0xFFF87171) : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Qty: ',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                      Text(
                        item.formattedQuantity,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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

  Widget _buildDaysLeftBadge(OwnerExpiryListItem item) {
    if (item.isExpired || item.daysLeft <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
            const SizedBox(width: 4),
            Text(
              'EXPIRED',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      );
    }

    final isUpcoming = item.daysLeft <= 30;
    final color = isUpcoming ? const Color(0xFFF97316) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        item.statusBadgeText,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
