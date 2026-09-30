import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_breakpoints.dart';
import '../../core/theme/glass_widgets.dart';
import '../../data/models/vendor_model.dart';
import '../../core/utils/text_standardizer.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/search_bar_widget.dart';
import '../../shared/widgets/standardized_text_field.dart';
import '../providers/app_providers.dart';
import '../providers/spelling_providers.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  const VendorsScreen({super.key, this.isEmbedded = false});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen> {
  String _search = '';

  Future<void> _showVendorDialog([VendorModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final placeCtrl = TextEditingController(text: existing?.place ?? '');
    final pinCtrl = TextEditingController(text: existing?.pincode ?? '');
    final gstinCtrl = TextEditingController(text: existing?.gstin ?? '');
    final matCtrl = TextEditingController(text: existing?.material ?? '');
    final infoCtrl = TextEditingController(text: existing?.info ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        final vendorsAsync = ref.read(dynamicVendorsProvider);
        final existingVendors = vendorsAsync.asData?.value ?? const [];

        return AlertDialog(
          title: Text(existing == null ? 'Add New Vendor' : 'Edit Vendor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StandardizedTextField(
                  controller: nameCtrl,
                  labelText: 'Vendor Name *',
                  hintText: 'e.g. SUPREME TEA SUPPLIERS',
                  prefixIcon: const Icon(Icons.storefront),
                  referenceCandidates: existingVendors,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contactCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone / Contact', prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: StandardizedTextField(
                        controller: placeCtrl,
                        labelText: 'Place / City',
                        hintText: 'e.g. COONOOR',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Pincode'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StandardizedTextField(
                  controller: gstinCtrl,
                  isCodeField: true,
                  labelText: 'GSTIN Number',
                  hintText: 'e.g. 33AAAAA0000A1Z5',
                ),
                const SizedBox(height: 10),
                StandardizedTextField(
                  controller: matCtrl,
                  labelText: 'Supplied Materials',
                  hintText: 'e.g. TEA, PACKAGING',
                ),
                const SizedBox(height: 10),
                StandardizedTextField(
                  controller: infoCtrl,
                  labelText: 'Notes / Info',
                  hintText: 'e.g. PRIMARY DISTRIBUTOR',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            GlassButton(
              text: 'Save Vendor',
              height: 40,
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final vendor = VendorModel(
        id: existing?.id ?? 0,
        name: TextStandardizer.normalizeBusinessText(nameCtrl.text),
        contact: contactCtrl.text.trim(),
        place: TextStandardizer.normalizeBusinessText(placeCtrl.text),
        pincode: pinCtrl.text.trim(),
        gstin: TextStandardizer.normalizeCode(gstinCtrl.text),
        material: TextStandardizer.normalizeBusinessText(matCtrl.text),
        info: TextStandardizer.normalizeBusinessText(infoCtrl.text),
      );

      final repo = ref.read(vendorsRepositoryProvider);
      if (existing == null) {
        await repo.addVendor(vendor);
      } else {
        await repo.updateVendor(vendor);
      }

      ref.invalidate(vendorsListProvider);
      ref.invalidate(dynamicVendorsProvider);
    }
  }

  Future<void> _deleteVendor(VendorModel v) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Vendor "${v.name}"?',
      message: 'Are you sure you want to remove this vendor from the directory?',
      confirmText: 'Yes, Delete',
      isDestructive: true,
    );

    if (confirmed) {
      await ref.read(vendorsRepositoryProvider).deleteVendor(v.id);
      ref.invalidate(vendorsListProvider);
    }
  }

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsListProvider(_search.isEmpty ? null : _search));
    final isTablet = ResponsiveBreakpoints.isTabletOrLarger(context);

    return Scaffold(
      appBar: widget.isEmbedded ? null : AppBar(title: const Text('Vendor Directory')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Vendor'),
        onPressed: () => _showVendorDialog(),
      ),
      body: AmbientBackground(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xB30F172A),
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: SearchBarWidget(
                hintText: 'Search vendor by name, GSTIN, place, or materials...',
                onChanged: (val) => setState(() => _search = val.trim()),
              ),
            ),
            Expanded(
              child: vendorsAsync.when(
                loading: () => const LoadingSkeletonList(count: 4),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.danger))),
                data: (vendors) {
                  if (vendors.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.storefront_outlined,
                      title: 'No vendors found',
                      message: 'Add your raw material suppliers and packaging vendors.',
                      actionLabel: '+ Add First Vendor',
                      onAction: () => _showVendorDialog(),
                    );
                  }

                  if (isTablet) {
                    return _buildTabletTable(vendors);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: vendors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final v = vendors[i];
                      return GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    v.name,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.accent),
                                      onPressed: () => _showVendorDialog(v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                      onPressed: () => _deleteVendor(v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (v.contact.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => _callPhone(v.contact),
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.success),
                                    const SizedBox(width: 6),
                                    Text(
                                      v.contact,
                                      style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (v.place.isNotEmpty || v.gstin.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (v.place.isNotEmpty)
                                    Text('Location: ${v.place}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  if (v.place.isNotEmpty && v.gstin.isNotEmpty) const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                  if (v.gstin.isNotEmpty)
                                    Text('GSTIN: ${v.gstin}', style: const TextStyle(fontSize: 11, color: AppColors.primaryLight)),
                                ],
                              ),
                            ],
                            if (v.material.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Supplies: ${v.material}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
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

  Widget _buildTabletTable(List<VendorModel> vendors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0x33020617)),
          columns: const [
            DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Place', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('GSTIN', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Materials', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: vendors.map((v) {
            return DataRow(
              cells: [
                DataCell(Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                DataCell(
                  InkWell(
                    onTap: () => _callPhone(v.contact),
                    child: Text(v.contact, style: const TextStyle(color: AppColors.success)),
                  ),
                ),
                DataCell(Text(v.place)),
                DataCell(Text(v.gstin, style: const TextStyle(color: AppColors.primaryLight))),
                DataCell(Text(v.material)),
                DataCell(
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 16, color: AppColors.accent), onPressed: () => _showVendorDialog(v)),
                      IconButton(icon: const Icon(Icons.delete, size: 16, color: AppColors.danger), onPressed: () => _deleteVendor(v)),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
