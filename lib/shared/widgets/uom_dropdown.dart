import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/factory_constants.dart';

class UomDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? labelText;
  final bool isExpanded;
  final bool isDense;
  final FormFieldValidator<String>? validator;
  final EdgeInsetsGeometry? contentPadding;

  const UomDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = 'Unit of Measure (UOM)',
    this.isExpanded = true,
    this.isDense = true,
    this.validator,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedValue = FactoryConstants.normalizeUomCode(value);

    // Ensure value exists in item list to avoid Flutter Dropdown assertion error
    final allItems = <UomItem>[...FactoryConstants.uomList];
    final exists = allItems.any((item) => item.code.toLowerCase() == normalizedValue.toLowerCase());

    if (!exists && normalizedValue.isNotEmpty) {
      allItems.add(UomItem(
        code: normalizedValue,
        label: normalizedValue,
        symbol: normalizedValue,
      ));
    }

    final selectedCode = exists
        ? allItems.firstWhere((item) => item.code.toLowerCase() == normalizedValue.toLowerCase()).code
        : (normalizedValue.isNotEmpty ? normalizedValue : 'kg');

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
      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryLight, size: 22),
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: const Icon(Icons.scale_outlined, size: 18, color: AppColors.primaryLight),
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: validator,
      onChanged: onChanged,
      items: allItems.map((uom) {
        return DropdownMenuItem<String>(
          value: uom.code,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                uom.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  uom.symbol,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
