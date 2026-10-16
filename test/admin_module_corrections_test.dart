import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/data/models/invoice_model.dart';

void main() {
  group('Admin Module Corrections - Brand & Invoice Model', () {
    test('InvoiceModel properly serializes and deserializes brand field', () {
      final json = {
        'id': 101,
        'purchase_id': 'PUR-99',
        'date': '2026-10-15',
        'invoice_no': 'INV-20261015-01',
        'vendor': 'Tata Tea Limited',
        'brand': 'Tata Tea Gold',
        'no_of_items': 1,
        'round_off_value': 0.0,
        'payment_status': 'Pending',
        'remarks': 'Test invoice with brand',
        'invoice_items': [
          {
            'id': 1,
            'invoice_id': 101,
            'material': 'TEA-BOP-01',
            'quantity': 50.0,
            'unit': 'kg',
            'unit_price': 250.0,
            'grade': 'BOP',
          }
        ]
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.id, 101);
      expect(invoice.vendor, 'Tata Tea Limited');
      expect(invoice.brand, 'Tata Tea Gold');
      expect(invoice.items.length, 1);
      expect(invoice.items.first.grade, 'BOP');

      final serialized = invoice.toJson();
      expect(serialized['vendor'], 'Tata Tea Limited');
      expect(serialized['brand'], 'Tata Tea Gold');
    });

    test('InvoiceModel defaults brand to empty string when absent (backward compatibility)', () {
      final json = {
        'id': 102,
        'invoice_no': 'INV-OLD-01',
        'vendor': 'Legacy Vendor',
        // 'brand' intentionally missing
        'invoice_items': []
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.vendor, 'Legacy Vendor');
      expect(invoice.brand, '');
      expect(invoice.toJson()['brand'], '');
    });
  });
}
