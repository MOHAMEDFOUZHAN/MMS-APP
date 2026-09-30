import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';

class NewMaterialDialog extends ConsumerStatefulWidget {
  const NewMaterialDialog({super.key});

  @override
  ConsumerState<NewMaterialDialog> createState() => _NewMaterialDialogState();
}

class _NewMaterialDialogState extends ConsumerState<NewMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _reorderController = TextEditingController(text: '0');
  final _hsnController = TextEditingController();
  final _gradeController = TextEditingController(text: 'STANDARD');

  String _selectedCategory = 'CHOCOLATE';
  String _selectedUnit = 'KG';
  bool _isCustomCategory = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _descController.dispose();
    _customCategoryController.dispose();
    _reorderController.dispose();
    _hsnController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final finalCategory = _isCustomCategory
        ? TextStandardizer.normalizeBusinessText(_customCategoryController.text)
        : _selectedCategory;

    try {
      final repo = ref.read(materialsRepositoryProvider);
      await repo.registerNewMaterial(
        code: TextStandardizer.normalizeCode(_codeController.text),
        description: TextStandardizer.normalizeBusinessText(_descController.text),
        category: finalCategory,
        unit: TextStandardizer.normalizeBusinessText(_selectedUnit),
        reorderLevel: double.tryParse(_reorderController.text) ?? 0.0,
        hsnSac: TextStandardizer.normalizeBusinessText(_hsnController.text),
        grade: TextStandardizer.normalizeBusinessText(_gradeController.text),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(dynamicCategoriesProvider);
    final descriptionsAsync = ref.watch(dynamicDescriptionsProvider);

    final existingDescriptions = descriptionsAsync.asData?.value ?? const [];
    final existingCategories = categoriesAsync.asData?.value ?? const [
      'CHOCOLATE', 'TEA', 'SPICES', 'DRY FRUITS', 'OIL', 'VARKEY FACTORY', 'PACKING', 'GENERAL'
    ];

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_box_rounded, color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'New Material Master',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Material Code (Standardized Uppercase, No Spaces)
              StandardizedTextField(
                controller: _codeController,
                isCodeField: true,
                labelText: 'Material Code *',
                hintText: 'e.g. 501 or TEA-PKG',
                prefixIcon: const Icon(Icons.qr_code, size: 18),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Material code is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 2. Description (Standardized with Dynamic Spelling Suggestions)
              StandardizedTextField(
                controller: _descController,
                labelText: 'Description / Item Name *',
                hintText: 'e.g. GREEN TEA POWDER',
                prefixIcon: const Icon(Icons.description_outlined, size: 18),
                referenceCandidates: existingDescriptions,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 3. Category Selection or Custom with Spelling Suggestion
              if (!_isCustomCategory) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: existingCategories.contains(_selectedCategory)
                            ? _selectedCategory
                            : (existingCategories.isNotEmpty ? existingCategories.first : 'CHOCOLATE'),
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(labelText: 'Category *'),
                        items: existingCategories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primaryLight),
                      tooltip: 'Type New Category',
                      onPressed: () => setState(() => _isCustomCategory = true),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: StandardizedTextField(
                        controller: _customCategoryController,
                        labelText: 'New Category Name *',
                        hintText: 'e.g. HERBAL EXTRACTS',
                        prefixIcon: const Icon(Icons.category_outlined, size: 18),
                        referenceCandidates: existingCategories,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Category required';
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt_rounded, size: 20, color: AppColors.textSecondary),
                      tooltip: 'Choose from list',
                      onPressed: () => setState(() => _isCustomCategory = false),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // 4. Unit (UOM)
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Unit of Measure (UOM) *'),
                items: const [
                  'KG', 'BOX', 'BAGS', 'CARTON', 'PCS', 'TIN', 'CAN', 'BOTTLE', 'ROLL', 'LTR', 'NOS', 'PKT'
                ].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedUnit = val);
                },
              ),
              const SizedBox(height: 12),

              // 5. Reorder Level
              TextFormField(
                controller: _reorderController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Reorder Level Threshold',
                  hintText: '0',
                  prefixIcon: Icon(Icons.warning_amber_rounded, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // 6. Grade & HSN/SAC
              Row(
                children: [
                  Expanded(
                    child: StandardizedTextField(
                      controller: _gradeController,
                      labelText: 'Grade',
                      hintText: 'STANDARD',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StandardizedTextField(
                      controller: _hsnController,
                      labelText: 'HSN / SAC',
                      hintText: 'e.g. 0902',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        GlassButton(
          text: 'Register Master',
          height: 40,
          isLoading: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
