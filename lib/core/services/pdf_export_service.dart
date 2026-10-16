import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/batch_model.dart';
import '../../data/models/dispatch_model.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/material_model.dart';
import '../../data/models/report_models.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/tea_material_received_model.dart';
import '../formatters/app_date_formatter.dart';
import '../formatters/quantity_formatter.dart';

class PdfExportService {
  static const PdfColor _brandPrimary = PdfColor.fromInt(0xFF6366F1);
  static const PdfColor _tableHeaderBg = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  static Future<void> _outputPdf(pw.Document pdf, String filename, {bool share = false}) async {
    final Uint8List bytes = await pdf.save();
    if (share) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    }
  }

  /// =========================================================================
  /// 1. PROFESSIONAL TAX INVOICE / PURCHASE VOUCHER PDF (A4)
  /// =========================================================================
  static Future<void> printInvoice(InvoiceModel invoice, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildInvoiceHeader(invoice),
        build: (context) => [
          _buildInvoiceDetailsSection(invoice),
          pw.SizedBox(height: 14),
          _buildInvoiceItemsTable(invoice),
          pw.SizedBox(height: 14),
          _buildInvoiceTotalsSection(invoice),
          pw.SizedBox(height: 24),
          _buildSignatorySection(),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Material Management System'),
      ),
    );

    final filename = 'Invoice_${invoice.invoiceNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
    await _outputPdf(pdf, filename, share: share);
  }

  static pw.Widget _buildInvoiceHeader(InvoiceModel invoice) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BENCHMARK MMS',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _brandPrimary)),
              pw.Text('Material Management & Inward System',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text('Confidential Inventory & Purchase Record',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PURCHASE INVOICE',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.Text('Status: ${invoice.paymentStatus.toUpperCase()}',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: invoice.paymentStatus.toLowerCase() == 'paid'
                          ? PdfColors.green700
                          : PdfColors.orange700)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceDetailsSection(InvoiceModel invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _borderGrey, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Vendor Details
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('VENDOR / SUPPLIER:',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(invoice.vendor.isNotEmpty ? invoice.vendor : 'Standard Vendor',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (invoice.remarks.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text('Remarks: ${invoice.remarks}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ],
            ),
          ),
          // Invoice Metadata
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildKeyVal('Invoice No:', invoice.invoiceNo),
                _buildKeyVal('Invoice Date:', QuantityFormatter.formatDate(invoice.date)),
                if (invoice.purchaseId.isNotEmpty)
                  _buildKeyVal('Purchase ID:', invoice.purchaseId),
                _buildKeyVal('Line Items:', invoice.items.isNotEmpty ? '${invoice.items.length}' : '${invoice.noOfItems}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKeyVal(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceItemsTable(InvoiceModel invoice) {
    final headers = [
      '#',
      'Material Code',
      'Lot No',
      'HSN/SAC',
      'Qty',
      'Unit',
      'Rate (INR)',
      'Disc %',
      'Net Amt',
      'GST %',
      'Total (INR)'
    ];

    final data = invoice.items.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final it = entry.value;
      final gst = it.gstPercentage > 0 ? it.gstPercentage : it.igstPercentage;
      final lot = it.lotNo.isNotEmpty ? it.lotNo : it.batchNo;
      return [
        idx.toString(),
        it.material,
        lot.isNotEmpty ? lot : '-',
        it.hsnSac.isNotEmpty ? it.hsnSac : '-',
        QuantityFormatter.format3Decimals(it.quantity),
        it.unit,
        it.unitPrice.toStringAsFixed(2),
        it.discountPercentage > 0 ? '${it.discountPercentage}%' : '0%',
        it.itemSubtotal.toStringAsFixed(2),
        '$gst%',
        it.itemTotal.toStringAsFixed(2),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.center,
        8: pw.Alignment.centerRight,
        9: pw.Alignment.center,
        10: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    );
  }

  static pw.Widget _buildInvoiceTotalsSection(InvoiceModel invoice) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Payment & Terms
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderGrey, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Terms & Notes:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('1. Goods received in good condition as per Benchmark MMS storage register.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                pw.Text('2. Tax calculation conforms to Indian GST framework (CGST/SGST/IGST).',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                pw.Text('3. Computer generated inward purchase voucher.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        // Financial summary table
        pw.Expanded(
          flex: 5,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _borderGrey, width: 0.8),
            ),
            child: pw.Column(
              children: [
                _buildTotalRow('Subtotal (Excl Tax):', 'INR ${invoice.totalExclTax.toStringAsFixed(2)}'),
                if (invoice.totalGst > 0)
                  _buildTotalRow('Total GST (CGST+SGST):', 'INR ${invoice.totalGst.toStringAsFixed(2)}'),
                if (invoice.totalIgst > 0)
                  _buildTotalRow('Total IGST:', 'INR ${invoice.totalIgst.toStringAsFixed(2)}'),
                if (invoice.roundOffValue != 0)
                  _buildTotalRow('Round Off:', 'INR ${invoice.roundOffValue.toStringAsFixed(2)}'),
                pw.Divider(thickness: 0.8, color: _brandPrimary),
                _buildTotalRow('Grand Total:', 'INR ${invoice.finalTotal.toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: isBold ? 9 : 8,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isBold ? _brandPrimary : PdfColors.grey800)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: isBold ? 10 : 8,
                  fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isBold ? _brandPrimary : PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatorySection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 140, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Store Keeper / Inward Inspector', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 140, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Authorized Signatory (Benchmark MMS)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  /// =========================================================================
  /// 2. MATERIAL DIRECTORY / WALL CHART
  /// =========================================================================
  static Future<void> printMaterialDirectory(List<MaterialDirectoryRow> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Material Directory / Wall Chart'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Category', 'Stock', 'Unit', 'Shelf Location'],
            data: rows.map((r) => [
              r.materialCode,
              r.description,
              r.category,
              QuantityFormatter.format3Decimals(r.currentStock),
              r.unit,
              r.shelfLocation,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Material Directory'),
      ),
    );

    await _outputPdf(pdf, 'Material_Directory_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 3. DAILY STOCK LEDGER (A4 Landscape)
  /// =========================================================================
  static Future<void> printDailyLedger(List<DailyLedgerRow> rows, DateTime date, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Daily Stock Ledger — ${QuantityFormatter.formatDate(date)}'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Opening', 'Inward (Pur)', 'Transfer Out', 'Return In', 'Dispatched', 'Closing', 'Unit'],
            data: rows.map((r) => [
              r.materialCode,
              r.description,
              QuantityFormatter.format3Decimals(r.openingStock),
              QuantityFormatter.format3Decimals(r.purchased),
              QuantityFormatter.format3Decimals(r.transferOut),
              QuantityFormatter.format3Decimals(r.returnIn),
              QuantityFormatter.format3Decimals(r.dispatched),
              QuantityFormatter.format3Decimals(r.closingStock),
              r.unit,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Daily Stock Ledger'),
      ),
    );

    await _outputPdf(pdf, 'Daily_Stock_Ledger_${QuantityFormatter.formatDate(date).replaceAll('/', '-')}.pdf', share: share);
  }

  /// =========================================================================
  /// 4. MATERIAL UTILIZATION REPORT (MUR) (A4 Landscape)
  /// =========================================================================
  static Future<void> printMurReport(List<MurReportRow> rows, DateTime start, DateTime end, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Material Utilization Report (MUR) — ${QuantityFormatter.formatDate(start)} to ${QuantityFormatter.formatDate(end)}'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Category', 'Opening', 'Purchased', 'Used', 'Closing', 'Unit', 'Util %'],
            data: rows.map((r) => [
              r.materialCode,
              r.description,
              r.category,
              QuantityFormatter.format3Decimals(r.opening),
              QuantityFormatter.format3Decimals(r.purchased),
              QuantityFormatter.format3Decimals(r.used),
              QuantityFormatter.format3Decimals(r.closing),
              r.unit,
              '${r.utilizationPercent.toStringAsFixed(1)}%',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • MUR Report'),
      ),
    );

    await _outputPdf(pdf, 'MUR_Report_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 5. DEPARTMENT CONSUMPTION REPORT
  /// =========================================================================
  static Future<void> printDepartmentConsumption(List<DepartmentConsumptionRow> rows, DateTime start, DateTime end, String dept, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Department Consumption ($dept) — ${QuantityFormatter.formatDate(start)} to ${QuantityFormatter.formatDate(end)}'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Department', 'Code', 'Description', 'Outward', 'Returned', 'Net Consumed', 'Unit'],
            data: rows.map((r) => [
              r.department,
              r.materialCode,
              r.description,
              QuantityFormatter.format3Decimals(r.totalOutward),
              QuantityFormatter.format3Decimals(r.totalReturn),
              QuantityFormatter.format3Decimals(r.netConsumed),
              r.unit,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Department Consumption'),
      ),
    );

    await _outputPdf(pdf, 'Department_Consumption_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// LIVE MATERIAL STOCK REPORT (A4 Landscape - Category-filtered & All)
  /// =========================================================================
  static Future<void> printLiveMaterialReport(
    List<MaterialModel> materials, {
    String? category,
    String? searchQuery,
    String? grade,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    bool share = false,
  }) async {
    final pdf = pw.Document();

    final categoryLabel = (category != null && category.isNotEmpty && category != 'All')
        ? 'Category: $category'
        : 'All Categories';

    final List<String> filterTags = [];
    filterTags.add(categoryLabel);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      filterTags.add('Search: "${searchQuery.trim()}"');
    }
    if (grade != null && grade.isNotEmpty && grade != 'All') {
      filterTags.add('Grade: $grade');
    }
    if (status != null && status.isNotEmpty && status != 'all') {
      filterTags.add('Status: ${status.replaceAll('_', ' ').toUpperCase()}');
    }
    if (fromDate != null && toDate != null) {
      filterTags.add('Period: ${QuantityFormatter.formatDate(fromDate)} to ${QuantityFormatter.formatDate(toDate)}');
    }

    final subtitle = filterTags.join('  •  ');

    final headers = [
      'Code',
      'Material Description',
      'Category',
      'Unit',
      'Opening',
      'Inward (+)',
      'Transfer (-)',
      'Return (+)',
      'Closing Stock',
      'Reorder',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        header: (context) => _buildReportHeader('Live Material Stock Report', subtitle: subtitle),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: materials.map((m) {
              return [
                m.materialCode,
                m.description.isNotEmpty ? m.description : '-',
                m.category,
                m.unit,
                QuantityFormatter.formatClean(m.openingStock),
                QuantityFormatter.formatClean(m.purchased),
                QuantityFormatter.formatClean(m.transferOut),
                QuantityFormatter.formatClean(m.returnIn),
                QuantityFormatter.formatClean(m.closingStock),
                m.reorderLevel > 0 ? QuantityFormatter.formatClean(m.reorderLevel) : '—',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.centerRight,
              9: pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: _borderGrey, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Items: ${materials.length}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.Text('Report Scope: $categoryLabel',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
        footer: (context) => _buildCleanFooter(context, 'Benchmark MMS • Live Material Stock Report'),
      ),
    );

    final cleanCat = (category != null && category.isNotEmpty && category != 'All')
        ? category.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
        : 'All_Categories';
    final filename = 'Live_Material_Stock_${cleanCat}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _outputPdf(pdf, filename, share: share);
  }

  /// =========================================================================
  /// 6. REORDER LEVEL REPORT
  /// =========================================================================
  static Future<void> printReorderReport(List<MaterialModel> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Reorder Level Alert Report'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Category', 'Current Stock', 'Reorder Level', 'Deficit', 'Unit'],
            data: rows.map((r) {
              final deficit = (r.reorderLevel - r.quantity).clamp(0.0, double.infinity);
              return [
                r.materialCode,
                r.description,
                r.category,
                QuantityFormatter.format3Decimals(r.quantity),
                QuantityFormatter.format3Decimals(r.reorderLevel),
                QuantityFormatter.format3Decimals(deficit),
                r.unit,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF59E0B)),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Reorder Alert Report'),
      ),
    );

    await _outputPdf(pdf, 'Reorder_Report_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 7. STORAGE REGISTER REPORT (A4 Landscape - Current Stock / All History)
  /// =========================================================================
  static Future<void> printStorageReport(
    List<BatchModel> rows, {
    bool isAllHistory = false,
    String? subtitle,
    String? dateFilter,
    bool share = false,
  }) async {
    // Current Storage Print: ONLY batches with available_quantity > 0 appear
    final List<BatchModel> toPrint = isAllHistory
        ? rows
        : rows.where((b) => b.availableQuantity > 0.0001).toList();

    final pdf = pw.Document();

    final title = isAllHistory ? 'Storage History' : 'Storage Register';

    final headerSubtitle = (dateFilter != null && dateFilter.isNotEmpty)
        ? (subtitle != null ? '$subtitle | Date Filter: $dateFilter' : 'Date Filter: $dateFilter')
        : subtitle;

    final headers = ['Date', 'Time', 'Batch No', 'Description', 'Department', 'Stock In', 'Availability'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildCleanReportHeader(title, subtitle: headerSubtitle),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: toPrint.map((b) {
              final d = AppDateFormatter.format(b.effectiveDate);
              final t = AppDateFormatter.formatTime(b.effectiveDateTime);
              final desc = b.description.isNotEmpty ? b.description : b.materialCode;
              final dept = b.department.isNotEmpty ? b.department : 'Finished Goods';
              final inQty = QuantityFormatter.formatDualUnit(b.receivedQuantity, b.uom);
              final avail = QuantityFormatter.formatDualUnit(b.availableQuantity, b.uom);

              return [
                d,
                t,
                b.batchNo,
                desc,
                dept,
                inQty,
                avail,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
        ],
        footer: (context) => _buildCleanFooter(context, title),
      ),
    );

    final prefix = isAllHistory ? 'Storage_History' : 'Storage_Register';
    await _outputPdf(pdf, '${prefix}_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  static Future<void> printStorageBatches(
    List<BatchModel> rows, {
    bool isAllHistory = false,
    String? subtitle,
    String? dateFilter,
    bool share = false,
  }) =>
      printStorageReport(rows, isAllHistory: isAllHistory, subtitle: subtitle, dateFilter: dateFilter, share: share);

  /// =========================================================================
  /// 8. OUT OF STOCK REPORT
  /// =========================================================================
  static Future<void> printOutOfStockReport(List<MaterialModel> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Out of Stock Materials Report'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Category', 'Stock', 'Unit', 'Reorder Level', 'Lot No'],
            data: rows.map((r) => [
              r.materialCode,
              r.description,
              r.category,
              '0.000',
              r.unit,
              QuantityFormatter.format3Decimals(r.reorderLevel),
              r.lotNo.isNotEmpty ? r.lotNo : '-',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEF4444)),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Out of Stock Report'),
      ),
    );

    await _outputPdf(pdf, 'Out_Of_Stock_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 9. EXPIRING ITEMS REPORT
  /// =========================================================================
  static Future<void> printExpiringReport(List<MaterialModel> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Shelf-Life Expiry Alert Report (<= 30 Days)'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Description', 'Lot No', 'Current Stock', 'Unit', 'Expiry Date', 'Status'],
            data: rows.map((r) {
              final daysLeft = r.expiryDate?.difference(DateTime.now()).inDays;
              final status = daysLeft == null
                  ? '-'
                  : daysLeft < 0
                      ? 'EXPIRED (${-daysLeft}d ago)'
                      : '$daysLeft days left';
              return [
                r.materialCode,
                r.description,
                r.lotNo.isNotEmpty ? r.lotNo : '-',
                QuantityFormatter.format3Decimals(r.quantity),
                r.unit,
                r.expiryDate != null ? QuantityFormatter.formatDate(r.expiryDate!) : '-',
                status,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF97316)),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Expiry Report'),
      ),
    );

    await _outputPdf(pdf, 'Expiring_Report_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 10. INVOICES REGISTER REPORT (A4 Landscape)
  /// =========================================================================
  static Future<void> printInvoicesReport(List<InvoiceModel> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Purchase Invoices Register'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Invoice No', 'Vendor', 'Items', 'Subtotal (INR)', 'GST (INR)', 'Grand Total (INR)', 'Status'],
            data: rows.map((inv) => [
              QuantityFormatter.formatDate(inv.date),
              inv.invoiceNo,
              inv.vendor,
              inv.items.isNotEmpty ? '${inv.items.length}' : '${inv.noOfItems}',
              inv.totalExclTax.toStringAsFixed(2),
              inv.totalGst.toStringAsFixed(2),
              inv.finalTotal.toStringAsFixed(2),
              inv.paymentStatus,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.center,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Invoices Register'),
      ),
    );

    await _outputPdf(pdf, 'Invoices_Report_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 11. TRANSFERS REGISTER REPORT (A4 Landscape)
  /// =========================================================================
  static Future<void> printTransfersReport(List<TransferModel> rows, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildReportHeader('Internal Transfers & Returns Register'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Code', 'Description', 'Lot No', 'Outward', 'Returned', 'Net Change', 'Balance', 'Dept', 'Person'],
            data: rows.map((t) => [
              QuantityFormatter.formatDate(t.date),
              t.code,
              t.description,
              t.lotNo.isNotEmpty ? t.lotNo : '-',
              QuantityFormatter.format3Decimals(t.outward),
              QuantityFormatter.format3Decimals(t.returnUnits),
              QuantityFormatter.format3Decimals(t.netChange),
              QuantityFormatter.format3Decimals(t.availability),
              t.department,
              t.person,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
        footer: (context) => _buildFooter(context, 'Benchmark MMS • Transfers Register'),
      ),
    );

    await _outputPdf(pdf, 'Transfers_Report_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  /// =========================================================================
  /// 12. DISPATCHES REGISTER REPORT (A4 Landscape)
  /// =========================================================================
  static Future<void> printDispatchesReport(
    List<DispatchModel> rows, {
    String? subtitle,
    bool share = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildCleanReportHeader('Dispatch Register', subtitle: subtitle),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Time',
              'Batch No',
              'Description',
              'Stock Out',
              'Units',
              'Location',
              'Department',
              'Return Qty',
            ],
            data: rows.map((d) {
              final batches = d.allocations.map((a) => '${a.batchNo} (${QuantityFormatter.formatClean(a.quantity)})').join(', ');
              return [
                AppDateFormatter.format(d.date),
                AppDateFormatter.formatTime(d.effectiveDateTime),
                batches.isNotEmpty ? batches : '-',
                d.displayName,
                QuantityFormatter.formatClean(d.quantity),
                d.units,
                d.location.isNotEmpty ? d.location : '-',
                d.department.isNotEmpty ? d.department : 'Dispatch',
                d.returnQuantity > 0 ? QuantityFormatter.formatClean(d.returnQuantity) : '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
              6: pw.Alignment.centerLeft,
              7: pw.Alignment.centerLeft,
              8: pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
        ],
        footer: (context) => _buildCleanFooter(context, 'Dispatch Register'),
      ),
    );

    await _outputPdf(pdf, 'Dispatch_Register_${DateTime.now().millisecondsSinceEpoch}.pdf', share: share);
  }

  static pw.Widget _buildCleanReportHeader(String title, {String? subtitle}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ],
          ),
          pw.Text('Generated: ${AppDateFormatter.formatWithTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  /// =========================================================================
  /// TEA MATERIAL RECEIVED LIVE STOCK LEDGER PDF (A4 Landscape)
  /// =========================================================================
  static Future<void> printTeaMaterialReceivedLedger(List<TeaMaterialReceivedModel> items, {bool share = false}) async {
    final pdf = pw.Document();

    final tableData = <List<String>>[
      ['Code', 'Description', 'Category', 'Unit', 'Received', 'Consumed', 'Returned', 'Available', 'Status', 'Latest Tx'],
      ...items.map((it) => [
        it.materialCode,
        it.description,
        it.category,
        it.unit,
        QuantityFormatter.formatClean(it.totalReceived),
        QuantityFormatter.formatClean(it.totalConsumed),
        QuantityFormatter.formatClean(it.totalReturned),
        QuantityFormatter.formatClean(it.currentBalance),
        it.stockStatus.replaceAll('_', ' '),
        it.latestTransactionAt != null ? AppDateFormatter.format(it.latestTransactionAt) : '-',
      ]),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        header: (context) => _buildReportHeader('TEA DEPARTMENT • LIVE STOCK LEDGER', subtitle: 'Material Received, Consumption & Confirmed Returns'),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: tableData[0],
            data: tableData.sublist(1),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderGrey, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
              7: pw.Alignment.centerRight,
              8: pw.Alignment.center,
              9: pw.Alignment.center,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: _borderGrey, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Materials: ${items.length}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.Text('Report Date: ${AppDateFormatter.formatWithTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
        footer: (context) => _buildCleanFooter(context, 'Benchmark MMS • Tea Department Stock Ledger'),
      ),
    );

    final filename = 'Tea_Material_Received_Ledger_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _outputPdf(pdf, filename, share: share);
  }

  static pw.Widget _buildCleanFooter(pw.Context context, String label) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildReportHeader(String title, {String? subtitle}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brandPrimary, width: 1.5)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BENCHMARK MMS',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _brandPrimary)),
              pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (subtitle != null && subtitle.isNotEmpty)
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
          pw.Text('Generated: ${AppDateFormatter.formatWithTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, String label) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }
}
