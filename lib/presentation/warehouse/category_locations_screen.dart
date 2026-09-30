import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/category_location_model.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';

class CategoryLocationsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const CategoryLocationsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<CategoryLocationsScreen> createState() => _CategoryLocationsScreenState();
}

class _CategoryLocationsScreenState extends ConsumerState<CategoryLocationsScreen> {
  String _search = '';

  Future<void> _editLocation(CategoryLocationModel item) async {
    final locCtrl = TextEditingController(text: item.location);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Shelf Location: ${item.category}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: locCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Warehouse Rack / Shelf / Bin',
                  hintText: 'e.g. Shelf A-2 (Ground Bay)',
                  prefixIcon: Icon(Icons.grid_view_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            GlassButton(
              text: 'Save Location',
              height: 40,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (saved == true && locCtrl.text.trim().isNotEmpty) {
      final normalizedLoc = TextStandardizer.normalizeBusinessText(locCtrl.text);
      await ref.read(warehouseRepositoryProvider).saveCategoryLocation(
            item.category,
            normalizedLoc,
          );
      ref.invalidate(categoryLocationsProvider);
    }
  }

  Future<void> _addNewCategoryLocation() async {
    final catCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final categoriesAsync = ref.read(dynamicCategoriesProvider);
    final existingCategories = categoriesAsync.asData?.value ?? const [];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Category Shelf Mapping'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardizedTextField(
                controller: catCtrl,
                labelText: 'Category Name *',
                hintText: 'e.g. TEA or CHOCOLATE',
                referenceCandidates: existingCategories,
              ),
              const SizedBox(height: 12),
              StandardizedTextField(
                controller: locCtrl,
                labelText: 'Shelf / Rack / Bin Location *',
                hintText: 'e.g. RACK C-1 (UPSTAIRS)',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            GlassButton(
              text: 'Add Mapping',
              height: 40,
              onPressed: () {
                if (catCtrl.text.trim().isEmpty || locCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final cleanCat = TextStandardizer.normalizeBusinessText(catCtrl.text);
      final cleanLoc = TextStandardizer.normalizeBusinessText(locCtrl.text);

      await ref.read(warehouseRepositoryProvider).saveCategoryLocation(
            cleanCat,
            cleanLoc,
          );
      ref.invalidate(categoryLocationsProvider);
      ref.invalidate(dynamicCategoriesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(categoryLocationsProvider);

    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(title: const Text('Category Shelf Locations')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Shelf'),
        onPressed: _addNewCategoryLocation,
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(
                hintText: 'Search category or rack/shelf location...',
                onChanged: (val) => setState(() => _search = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: locationsAsync.when(
                loading: () => const LoadingSkeletonList(count: 4),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (locations) {
                  final filtered = locations.where((l) {
                    if (_search.isEmpty) return true;
                    return l.category.toLowerCase().contains(_search) ||
                        l.location.toLowerCase().contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.grid_view_outlined,
                      title: 'No category locations found',
                      message: 'Map inventory categories to physical warehouse racks and shelves.',
                      actionLabel: '+ Add Mapping',
                      onAction: _addNewCategoryLocation,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shelves, color: Color(0xFFA78BFA), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.category,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.location.isNotEmpty ? item.location : 'Not Assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: item.location.isNotEmpty ? AppColors.accent : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryLight),
                              onPressed: () => _editLocation(item),
                            ),
                          ],
                        ),
                      );
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
}
