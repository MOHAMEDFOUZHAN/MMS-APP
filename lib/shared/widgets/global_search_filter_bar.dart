import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/formatters/app_date_formatter.dart';
import '../../core/theme/glass_widgets.dart';

class GlobalSearchFilterBar extends StatefulWidget {
  final String hintText;
  final String initialSearch;
  final DateTime? initialFromDate;
  final DateTime? initialToDate;
  final bool showDateFilter;
  final ValueChanged<String>? onSearchChanged;
  final void Function(String search, DateTime? fromDate, DateTime? toDate)? onApply;
  final VoidCallback? onClear;
  final Widget? trailingAction;

  const GlobalSearchFilterBar({
    super.key,
    this.hintText = 'Search by Code, Description or Category',
    this.initialSearch = '',
    this.initialFromDate,
    this.initialToDate,
    this.showDateFilter = true,
    this.onSearchChanged,
    this.onApply,
    this.onClear,
    this.trailingAction,
  });

  @override
  State<GlobalSearchFilterBar> createState() => _GlobalSearchFilterBarState();
}

class _GlobalSearchFilterBarState extends State<GlobalSearchFilterBar> {
  late final TextEditingController _searchController;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch);
    _fromDate = widget.initialFromDate;
    _toDate = widget.initialToDate;
  }

  @override
  void didUpdateWidget(covariant GlobalSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != oldWidget.initialSearch && widget.initialSearch != _searchController.text) {
      _searchController.text = widget.initialSearch;
    }
    if (widget.initialFromDate != oldWidget.initialFromDate) {
      _fromDate = widget.initialFromDate;
    }
    if (widget.initialToDate != oldWidget.initialToDate) {
      _toDate = widget.initialToDate;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String val) {
    widget.onSearchChanged?.call(val);
  }

  void _handleApply() {
    widget.onApply?.call(
      _searchController.text.trim(),
      _fromDate != null ? AppDateFormatter.startOfDay(_fromDate!) : null,
      _toDate != null ? AppDateFormatter.endOfDay(_toDate!) : null,
    );
  }

  void _handleClear() {
    setState(() {
      _searchController.clear();
      _fromDate = null;
      _toDate = null;
    });
    widget.onSearchChanged?.call('');
    widget.onClear?.call();
    widget.onApply?.call('', null, null);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => _buildDatePickerTheme(child),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => _buildDatePickerTheme(child),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  Widget _buildDatePickerTheme(Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          onPrimary: Colors.white,
          surface: Color(0xFF0F172A),
          onSurface: AppColors.textPrimary,
        ),
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0F172A)),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _searchController.text.isNotEmpty || _fromDate != null || _toDate != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xB30F172A),
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Unified Search Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _handleSearchChanged,
                  onSubmitted: (_) => _handleApply(),
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryLight),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              _handleSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: const Color(0x33020617),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                    ),
                  ),
                ),
              ),
              if (widget.trailingAction != null) ...[
                const SizedBox(width: 8),
                widget.trailingAction!,
              ],
            ],
          ),

          // Row 2: Date Filters & Action Buttons
          if (widget.showDateFilter) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // From Date Selector (DD/MM/YYYY)
                InkWell(
                  onTap: _pickFromDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x33020617),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _fromDate != null ? AppColors.primaryLight : AppColors.glassBorder,
                        width: _fromDate != null ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          _fromDate != null ? 'From: ${AppDateFormatter.format(_fromDate)}' : 'From Date (DD/MM/YYYY)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _fromDate != null ? FontWeight.w600 : FontWeight.normal,
                            color: _fromDate != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // To Date Selector (DD/MM/YYYY)
                InkWell(
                  onTap: _pickToDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x33020617),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _toDate != null ? AppColors.primaryLight : AppColors.glassBorder,
                        width: _toDate != null ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_outlined, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 6),
                        Text(
                          _toDate != null ? 'To: ${AppDateFormatter.format(_toDate)}' : 'To Date (DD/MM/YYYY)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: _toDate != null ? FontWeight.w600 : FontWeight.normal,
                            color: _toDate != null ? AppColors.textPrimary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search / Apply Button
                GlassButton(
                  text: 'Apply',
                  icon: Icons.filter_alt_outlined,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  onPressed: _handleApply,
                ),

                // Clear Button
                if (hasActiveFilter)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      side: const BorderSide(color: AppColors.glassBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    onPressed: _handleClear,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
