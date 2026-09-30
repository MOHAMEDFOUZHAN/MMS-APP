import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/material_model.dart';
import '../../data/repositories/materials_repository.dart';

/// Result returned when a user selects a material.
class MaterialSelection {
  final String code;
  final String description;
  final String category;
  final String unit;
  final String hsnSac;
  final String grade;
  final double reorderLevel;

  const MaterialSelection({
    required this.code,
    required this.description,
    required this.category,
    required this.unit,
    required this.hsnSac,
    required this.grade,
    required this.reorderLevel,
  });

  factory MaterialSelection.fromModel(MaterialModel m) => MaterialSelection(
        code: m.materialCode,
        description: m.description,
        category: m.category,
        unit: m.unit,
        hsnSac: m.hsnSac,
        grade: m.grade,
        reorderLevel: m.reorderLevel.toDouble(),
      );
}

/// A live-search dropdown for selecting a Material Master record.
/// Allows searching by Material Code OR Description.
class MaterialSearchWidget extends ConsumerStatefulWidget {
  final String labelText;
  final String? initialCode;
  final void Function(MaterialSelection) onSelected;
  final bool autofocus;

  const MaterialSearchWidget({
    super.key,
    this.labelText = 'Search Material (Code or Name)',
    this.initialCode,
    required this.onSelected,
    this.autofocus = false,
  });

  @override
  ConsumerState<MaterialSearchWidget> createState() => _MaterialSearchWidgetState();
}

class _MaterialSearchWidgetState extends ConsumerState<MaterialSearchWidget> {
  final _repo = MaterialsRepository();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  List<MaterialModel> _results = [];
  bool _loading = false;
  bool _showDropdown = false;
  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _controller.text = widget.initialCode!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _search(_controller.text);
    } else {
      _closeDropdown();
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final results = await _repo.searchMaterials(query, limit: 25);
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
          _showDropdown = true;
        });
        _updateOverlay();
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    });
  }

  void _select(MaterialModel m) {
    _controller.text = '${m.materialCode} — ${m.description}';
    _closeDropdown();
    _focusNode.unfocus();
    widget.onSelected(MaterialSelection.fromModel(m));
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _showDropdown = false);
  }

  void _updateOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!_showDropdown || (!mounted)) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _overlayEntry = OverlayEntry(builder: (_) => _buildDropdownOverlay());
    overlay.insert(_overlayEntry!);
  }

  Widget _buildDropdownOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(320, 50);

    return Stack(
      children: [
        // Transparent tap detector to close dropdown when tapping outside
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeDropdown,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: size.width,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColors.glassBorder,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final m = _results[i];
                          return InkWell(
                            onTap: () => _select(m),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  // Code chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      m.materialCode,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Description + category
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.description.isNotEmpty ? m.description : '—',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (m.category.isNotEmpty)
                                          Text(
                                            '${m.category} · ${m.unit}',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Unit badge
                                  Text(
                                    m.unit,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _overlayEntry?.remove();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: widget.labelText,
          labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _controller.clear();
                        _closeDropdown();
                      },
                    )
                  : null,
          filled: true,
          fillColor: const Color(0xFF1E2940),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.glassBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        onChanged: _search,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Please select a material';
          return null;
        },
      ),
    );
  }
}
