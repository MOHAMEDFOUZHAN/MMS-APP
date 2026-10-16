import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/app_exception.dart';
import '../models/chocolate_ocr_ledger_model.dart';

class ChocolateOcrRepository {
  ChocolateOcrRepository();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Fetch all confirmed Chocolate OCR ledger records, newest first
  Future<List<ChocolateOcrLedgerModel>> fetchLedger({int limit = 200}) async {
    try {
      final res = await _client
          .from('chocolate_ocr_ledger')
          .select()
          .order('confirmed_at', ascending: false)
          .limit(limit);

      return (res as List<dynamic>)
          .map((json) => ChocolateOcrLedgerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching chocolate OCR ledger: $e');
      throw AppException.from(e);
    }
  }

  /// Confirm and save a verified Chocolate OCR record permanently into the ledger.
  /// Enforces positive quantity validation and idempotency.
  /// Intentionally has NO corresponding update or delete operations (immutable).
  Future<ChocolateOcrLedgerModel> confirmEntry({
    required String description,
    required double quantity,
    String unit = 'KG',
    required double rawOcrQuantity,
    String? rawOcrText,
    String? documentName,
    required String idempotencyKey,
    String createdBy = 'chocolate',
  }) async {
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty) {
      throw AppException('Product description is required.');
    }

    if (quantity <= 0.0 || rawOcrQuantity <= 0.0) {
      throw AppException(
        'Invalid OCR Quantity: Confirmed quantity must be greater than 0. Cannot confirm missing or zero quantity.',
      );
    }

    try {
      final productCode = 'TRAY-${cleanDesc.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '')}';
      final cleanUnit = unit.toUpperCase().trim();

      // Upsert finished product identity into storage_products so Tray and Consign have it immediately
      try {
        await _client.rpc('upsert_storage_product', params: {
          'p_product_code': productCode,
          'p_product_name': cleanDesc,
          'p_uom': cleanUnit.toLowerCase(),
          'p_grade': 'STANDARD',
          'p_category': 'CHOCOLATE',
        });
      } catch (upsertErr) {
        debugPrint('Warning: non-critical upsert_storage_product warning: $upsertErr');
      }

      final payload = {
        'description': cleanDesc,
        'product_code': productCode,
        'quantity': quantity,
        'unit': cleanUnit,
        'raw_ocr_quantity': rawOcrQuantity,
        'raw_ocr_text': rawOcrText,
        'document_name': documentName,
        'status': 'CONFIRMED',
        'confirmed_at': DateTime.now().toUtc().toIso8601String(),
        'idempotency_key': idempotencyKey,
        'created_by': createdBy,
      };

      final res = await _client
          .from('chocolate_ocr_ledger')
          .insert(payload)
          .select()
          .single();

      return ChocolateOcrLedgerModel.fromJson(res);
    } catch (e) {
      // If error is duplicate key violation on idempotency_key, fetch and return the existing record
      if (e.toString().contains('duplicate key') || e.toString().contains('chocolate_ocr_ledger_idempotency_key_key')) {
        debugPrint('Duplicate confirmation detected with idempotency key: $idempotencyKey. Returning existing record.');
        final existing = await _client
            .from('chocolate_ocr_ledger')
            .select()
            .eq('idempotency_key', idempotencyKey)
            .maybeSingle();
        if (existing != null) {
          return ChocolateOcrLedgerModel.fromJson(existing);
        }
      }
      debugPrint('Error confirming chocolate OCR entry: $e');
      throw AppException.from(e);
    }
  }
}
