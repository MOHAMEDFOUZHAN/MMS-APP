import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/formatters/app_date_formatter.dart';
import '../../../core/formatters/quantity_formatter.dart';
import '../../../data/models/invoice_model.dart';

/// Reusable KPI Summary Chip for Owner Reports
class OwnerKpiChip extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;

  const OwnerKpiChip({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = const Color(0xFFF59E0B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable Search Input Field for Owner Reporting Tables
class OwnerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const OwnerSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search material code, description, category...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    controller.clear();
                    if (onClear != null) onClear!();
                    if (onChanged != null) onChanged!('');
                  },
                )
              : null,
          hintText: hintText,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/// Quick Date Filter Selector for Owner Portal
enum OwnerQuickDateFilter { today, last7Days, thisMonth, allTime, custom }

class OwnerDateFilterChips extends StatelessWidget {
  final OwnerQuickDateFilter selected;
  final ValueChanged<OwnerQuickDateFilter> onSelected;
  final VoidCallback? onPickCustom;
  final DateTime? customFrom;
  final DateTime? customTo;

  const OwnerDateFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onPickCustom,
    this.customFrom,
    this.customTo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildChip('Today', OwnerQuickDateFilter.today, Icons.today_rounded),
          const SizedBox(width: 6),
          _buildChip('Last 7 Days', OwnerQuickDateFilter.last7Days, Icons.date_range_rounded),
          const SizedBox(width: 6),
          _buildChip('All Time', OwnerQuickDateFilter.allTime, Icons.history_rounded),
          const SizedBox(width: 6),
          _buildCustomChip(),
        ],
      ),
    );
  }

  Widget _buildChip(String label, OwnerQuickDateFilter filter, IconData icon) {
    final isSelected = selected == filter;
    return InkWell(
      onTap: () => onSelected(filter),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.black : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomChip() {
    final isSelected = selected == OwnerQuickDateFilter.custom;
    String label = 'Custom';
    if (customFrom != null && customTo != null) {
      label = '${AppDateFormatter.format(customFrom)} - ${AppDateFormatter.format(customTo)}';
    }

    return InkWell(
      onTap: () {
        onSelected(OwnerQuickDateFilter.custom);
        if (onPickCustom != null) onPickCustom!();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 13,
              color: isSelected ? Colors.black : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-Only Invoice Details Modal Sheet
void showOwnerInvoiceDetailsModal(BuildContext context, InvoiceModel invoice) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0F172A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: Color(0xFF334155)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF06B6D4)),
                                ),
                                child: Text(
                                  'READ-ONLY INVOICE AUDIT',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF06B6D4),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (invoice.paymentStatus.toLowerCase() == 'paid')
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  invoice.paymentStatus.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: (invoice.paymentStatus.toLowerCase() == 'paid')
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Invoice #${invoice.invoiceNo.isNotEmpty ? invoice.invoiceNo : invoice.id}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (invoice.purchaseId.isNotEmpty)
                            Text(
                              'Purchase ID: ${invoice.purchaseId}',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Meta row: Vendor, Date, Items
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendor', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text(
                              invoice.vendor.isNotEmpty ? invoice.vendor : '—',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFF334155)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice Date & Time', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text(
                              '${AppDateFormatter.format(invoice.date)} ${AppDateFormatter.formatTime(invoice.effectiveDateTime)}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Items list title
                Text(
                  'INVOICE LINE ITEMS (${invoice.items.length})',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFCBD5E1),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // Line items cards
                if (invoice.items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'No line item records stored for this invoice.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...invoice.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.material,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rate: ₹${QuantityFormatter.formatClean(item.unitPrice)} / ${item.unit} • GST: ${QuantityFormatter.formatClean(item.gstPercentage)}%',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                                if (item.lotNo.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lot: ${item.lotNo}',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${QuantityFormatter.formatClean(item.quantity)} ${item.unit}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${QuantityFormatter.formatClean(item.itemTotal)}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 16),

                // Financial Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF374151)),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Subtotal (Excl. Tax)', '₹${QuantityFormatter.formatClean(invoice.totalExclTax)}'),
                      const SizedBox(height: 6),
                      _summaryRow('Total GST', '₹${QuantityFormatter.formatClean(invoice.totalGst + invoice.totalIgst)}'),
                      if (invoice.roundOffValue != 0.0) ...[
                        const SizedBox(height: 6),
                        _summaryRow('Round Off', '₹${QuantityFormatter.formatClean(invoice.roundOffValue)}'),
                      ],
                      const Divider(color: Color(0xFF374151), height: 16),
                      _summaryRow(
                        'Total Invoice Amount',
                        '₹${QuantityFormatter.formatClean(invoice.finalTotal)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                if (invoice.remarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Remarks: ${invoice.remarks}',
                    style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _summaryRow(String label, String value, {bool isTotal = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: isTotal ? 14 : 12,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          color: isTotal ? Colors.white : const Color(0xFF94A3B8),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.inter(
          fontSize: isTotal ? 16 : 12,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
          color: isTotal ? const Color(0xFF10B981) : Colors.white,
        ),
      ),
    ],
  );
}
