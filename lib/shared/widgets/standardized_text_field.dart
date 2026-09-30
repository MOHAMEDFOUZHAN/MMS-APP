import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/text_standardizer.dart';

/// Reusable Standardized Input Field with live UpperCase casing and
/// dynamic Fuzzy Spelling Suggestions.
///
/// Workflow:
/// User types -> Formatted in Uppercase -> Scanned against dynamic master reference
/// -> If typo detected, shows: Did you mean "CORRECT"? [Use CORRECT] [Keep as is]
class StandardizedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final List<String> referenceCandidates;
  final bool autoUppercase;
  final bool isCodeField;
  final int maxLines;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;

  const StandardizedTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.referenceCandidates = const [],
    this.autoUppercase = true,
    this.isCodeField = false,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  State<StandardizedTextField> createState() => _StandardizedTextFieldState();
}

class _StandardizedTextFieldState extends State<StandardizedTextField> {
  late final FocusNode _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  FuzzyMatchResult? _activeSuggestion;
  Timer? _debounceTimer;
  bool _dismissedForCurrentText = false;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_effectiveFocusNode.hasFocus) {
      // Normalize spaces on blur
      final normalized = widget.isCodeField
          ? TextStandardizer.normalizeCode(widget.controller.text)
          : TextStandardizer.normalizeBusinessText(widget.controller.text);
      if (widget.controller.text != normalized) {
        widget.controller.text = normalized;
      }
    }
  }

  void _checkSpelling(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || widget.referenceCandidates.isEmpty) return;

      final clean = TextStandardizer.normalizeBusinessText(value);
      if (clean.length < 3 || _dismissedForCurrentText) {
        if (_activeSuggestion != null) {
          setState(() => _activeSuggestion = null);
        }
        return;
      }

      final result = FuzzySpellingEngine.findBestSuggestion(
        clean,
        widget.referenceCandidates,
        minThreshold: 0.75,
      );

      if (mounted) {
        setState(() {
          _activeSuggestion = (result != null && result.hasSuggestion) ? result : null;
        });
      }
    });
  }

  void _applySuggestion(String suggested) {
    widget.controller.text = suggested;
    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: suggested.length));
    setState(() {
      _activeSuggestion = null;
      _dismissedForCurrentText = true;
    });
    if (widget.onChanged != null) widget.onChanged!(suggested);
  }

  void _dismissSuggestion() {
    setState(() {
      _activeSuggestion = null;
      _dismissedForCurrentText = true;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _effectiveFocusNode,
          maxLines: widget.maxLines,
          inputFormatters: [
            if (widget.autoUppercase) const UpperCaseTextFormatter(collapseMultipleSpaces: false),
          ],
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
          ),
          validator: widget.validator,
          onChanged: (val) {
            _dismissedForCurrentText = false;
            _checkSpelling(val);
            if (widget.onChanged != null) widget.onChanged!(val);
          },
          onFieldSubmitted: widget.onFieldSubmitted,
        ),

        // Live Spelling Suggestion Banner
        if (_activeSuggestion != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_fix_high_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                      children: [
                        const TextSpan(text: 'Did you mean "'),
                        TextSpan(
                          text: _activeSuggestion!.suggestedMatch,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent),
                        ),
                        const TextSpan(text: '"?'),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _applySuggestion(_activeSuggestion!.suggestedMatch),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(50, 26),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    foregroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Use', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  tooltip: 'Keep as entered',
                  onPressed: _dismissSuggestion,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
