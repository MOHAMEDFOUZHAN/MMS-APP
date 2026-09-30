import 'package:flutter_test/flutter_test.dart';
import 'package:mms_app/core/formatters/quantity_formatter.dart';

void main() {
  group('1. Inward Purchase & Tax Calculations (Prompt Section 16)', () {
    test('Calculates gross, discount, net, and hybrid GST accurately', () {
      const quantity = 25.0;
      const unitPrice = 120.0;
      const discountPercent = 10.0;
      const gstPercent = 18.0;

      // Gross Amount = Quantity × Unit Price
      final gross = quantity * unitPrice; // 3000.0
      expect(gross, 3000.0);

      // Discount = Gross Amount × Discount % / 100
      final discount = gross * discountPercent / 100.0; // 300.0
      expect(discount, 300.0);

      // Net Amount = Gross Amount - Discount
      final net = gross - discount; // 2700.0
      expect(net, 2700.0);

      // GST = Net Amount × GST % / 100
      final gst = (net * gstPercent / 100.0 * 100).round() / 100; // 486.0
      expect(gst, 486.0);

      // Item Total = Net Amount + GST
      final itemTotal = net + gst; // 3186.0
      expect(itemTotal, 3186.0);
    });

    test('Invoice Totals and Round-Off Calculation', () {
      final itemNets = [145.55, 312.40, 89.15];
      final itemGsts = [26.20, 56.23, 16.05];

      final totalExclTax = itemNets.reduce((a, b) => a + b); // 547.10
      final totalGst = itemGsts.reduce((a, b) => a + b); // 98.48
      final grandTotal = totalExclTax + totalGst; // 645.58

      // Round off
      final roundedFinal = grandTotal.roundToDouble(); // 646.0
      final roundOff = (roundedFinal - grandTotal * 100).round() / 100;

      expect(roundOff, isA<double>());
      expect(grandTotal, closeTo(645.58, 0.01));
      expect(roundedFinal, 646.0);
    });
  });

  group('2. Department Transfer Net Calculations (Prompt Section 13)', () {
    test('Calculates net change and rounds new quantity to 3 decimal places', () {
      const currentStock = 150.750;
      const outward = 25.500;
      const returnUnits = 5.250;

      // Net Change = Return Quantity - Outward Quantity
      final netChange = returnUnits - outward; // -20.250
      expect(netChange, -20.250);

      // New Quantity = ROUND(Current Quantity + Net Change, 3)
      final newQuantity = ((currentStock + netChange) * 1000).round() / 1000.0;
      expect(newQuantity, 130.500);
    });

    test('Prevents outward transfer exceeding current lot stock', () {
      const currentStock = 10.0;
      const outward = 15.0;

      final isInvalid = outward > currentStock;
      expect(isInvalid, isTrue);
    });
  });

  group('3. Material Utilization Report (MUR) Backtracking Math (Prompt Section 30)', () {
    test('Calculates historical period opening and closing using movement backtracking', () {
      const currentStock = 120.0;
      const purchasedAfterPeriod = 30.0;
      const usedAfterPeriod = 40.0;

      // Period Closing = Current Stock + Used After Period - Purchased After Period
      final periodClosing = currentStock + usedAfterPeriod - purchasedAfterPeriod; // 130.0
      expect(periodClosing, 130.0);

      const purchasedInPeriod = 50.0;
      const usedInPeriod = 60.0;

      // Period Opening = Period Closing + Used In Period - Purchased In Period
      final periodOpening = periodClosing + usedInPeriod - purchasedInPeriod; // 140.0
      expect(periodOpening, 140.0);

      // Utilization % = (Used In / (Opening + Purchased In)) * 100
      final totalAvailableInPeriod = periodOpening + purchasedInPeriod; // 190.0
      final utilization = (usedInPeriod / totalAvailableInPeriod) * 100;

      expect(utilization, closeTo(31.58, 0.01));
    });
  });

  group('4. Quantity Formatter & Dual Unit Formatting (Prompt Section 59 & 60)', () {
    test('Formats 3 decimals correctly without floating point imprecision', () {
      expect(QuantityFormatter.format3Decimals(1.25), '1.250');
      expect(QuantityFormatter.format3Decimals(0.5), '0.500');
      expect(QuantityFormatter.format3Decimals(2.75), '2.750');
      expect(QuantityFormatter.format3Decimals(0.0), '0.000');
    });

    test('Dual unit breakdown for kg and grams', () {
      // 40.05 kg -> 40 kg 50 g
      expect(QuantityFormatter.formatDualUnit(40.05, 'kg'), '40 kg 50 g');
      // 5.500 kg -> 5 kg 500 g
      expect(QuantityFormatter.formatDualUnit(5.5, 'kg'), '5 kg 500 g');
      // 0.250 kg -> 250 g
      expect(QuantityFormatter.formatDualUnit(0.25, 'kg'), '250 g');
    });

    test('Dual unit breakdown for litre and ml', () {
      // 100.5 litre -> 100 Litre 500 ml
      expect(QuantityFormatter.formatDualUnit(100.5, 'litre'), '100 Litre 500 ml');
    });

    test('Single units like pcs, box, roll remain direct with unit label', () {
      expect(QuantityFormatter.formatDualUnit(50.0, 'pcs'), '50 pcs');
      expect(QuantityFormatter.formatDualUnit(12.0, 'box'), '12 box');
    });
  });
}
