import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';

class GradeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? labelText;
  final bool isExpanded;
  final bool isDense;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry? contentPadding;

  const GradeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Tea Grade',
    this.isExpanded = true,
    this.isDense = true,
    this.validator,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = FactoryConstants.normalizeGradeCode(value);

    final allItems = <GradeItem>[...FactoryConstants.gradeList];
    final exists = allItems.any((item) => item.code.toUpperCase() == normalizedValue.toUpperCase());

    if (!exists && normalizedValue.isNotEmpty) {
      allItems.add(GradeItem(
        code: normalizedValue,
        name: normalizedValue,
      ));
    }

    final selectedCode = exists
        ? allItems.firstWhere((item) => item.code.toUpperCase() == normalizedValue.toUpperCase()).code
        : (normalizedValue.isNotEmpty ? normalizedValue : 'BP');

    return DropdownButtonFormField<String>(
      value: selectedCode,
      isExpanded: isExpanded,
      isDense: isDense,
      dropdownColor: const Color(0xFF0F172A),
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondary, size: 22),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.grade_outlined, size: 18, color: AppColors.secondary),
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: validator,
      onChanged: onChanged,
      items: allItems.map((grade) {
        return DropdownMenuItem<String>(
          value: grade.code,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  grade.code,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  grade.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
