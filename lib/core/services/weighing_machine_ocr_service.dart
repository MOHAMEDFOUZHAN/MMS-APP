import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'ocr_image_preprocessor.dart';

/// Represents a single captured frame sample for stability analysis
class WeighingSample {
  final double weight;
  final String? weightString;
  final String unit;
  final double confidence;
  final DateTime timestamp;
  final String? rawText;

  const WeighingSample({
    required this.weight,
    this.weightString,
    required this.unit,
    required this.confidence,
    required this.timestamp,
    this.rawText,
  });

  String get displayWeight {
    if (weightString != null && weightString!.isNotEmpty) {
      return '$weightString $unit';
    }
    if (weight % 1 == 0) {
      return '${weight.toInt()} $unit';
    }
    return '${weight.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")} $unit';
  }
}

/// Result of Weighing Machine LED OCR extraction
class WeighingOcrResult {
  final bool isValid;
  final double? numericWeight;
  final String? weightString; // Exact string representation e.g. "24" or "12.450"
  final String unit;
  final double confidence;
  final String? rawText;
  final String? errorMessage;
  final bool isStable;
  final List<WeighingSample> samples;
  final String? statusMessage;
  final String model;
  final int processingTimeMs;

  const WeighingOcrResult({
    required this.isValid,
    this.numericWeight,
    this.weightString,
    this.unit = 'KG',
    this.confidence = 0.0,
    this.rawText,
    this.errorMessage,
    this.isStable = true,
    this.samples = const [],
    this.statusMessage,
    this.model = 'RapidOCR PP-OCRv3 (ONNX)',
    this.processingTimeMs = 0,
  });

  String get displayWeight {
    if (weightString != null && weightString!.isNotEmpty) {
      return '$weightString $unit';
    }
    if (numericWeight != null) {
      if (numericWeight! % 1 == 0) {
        return '${numericWeight!.toInt()} $unit';
      }
      return '${numericWeight!.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")} $unit';
    }
    return '-- $unit';
  }
}

class _NumericCandidate {
  final String text;
  final double value;
  final double height;
  final double width;
  final double yCenter;
  final double xCenter;
  final double confidence;

  const _NumericCandidate({
    required this.text,
    required this.value,
    required this.height,
    required this.width,
    required this.yCenter,
    required this.xCenter,
    required this.confidence,
  });
}

class WeighingMachineOcrService {
  /// Primary weighing machine OCR entry point.
  /// 1. Attempts remote RapidOCR PP-OCRv3 (ONNX Runtime) endpoint if available.
  /// 2. Seamlessly falls back to on-device Google ML Kit + 7-segment digit & decimal analyzer if offline.
  static Future<WeighingOcrResult> parseWeighingIndicator(
    File imageFile, {
    List<WeighingSample> existingSamples = const [],
  }) async {
    final t0 = DateTime.now();

    // Verify file usability
    if (!imageFile.existsSync() || imageFile.lengthSync() <= 0) {
      return const WeighingOcrResult(
        isValid: false,
        errorMessage: 'Image file is empty or corrupted. Please capture the weighing machine display again.',
      );
    }

    // Normalize image (composite transparent PNG onto white background, scale up small images)
    final targetFile = await OcrImagePreprocessor.normalizeForOcr(imageFile);

    // 1. Try remote RapidOCR ONNX / PP-OCR endpoint if configured
    final endpoint = SupabaseConfig.ocrApiUrl;
    if (endpoint.isNotEmpty) {
      try {
        final base = endpoint.endsWith('/') ? endpoint.substring(0, endpoint.length - 1) : endpoint;
        final url = Uri.parse('$base/api/ocr/scan-weight');

        final request = http.MultipartRequest('POST', url);
        request.files.add(await http.MultipartFile.fromPath('file', targetFile.path));

        var response = await request.send().timeout(const Duration(seconds: 8));
        // Fallback to legacy endpoint if 404
        if (response.statusCode == 404) {
          final legacyUrl = Uri.parse('$base/api/ocr/weighing-machine');
          final legacyReq = http.MultipartRequest('POST', legacyUrl);
          legacyReq.files.add(await http.MultipartFile.fromPath('file', targetFile.path));
          response = await legacyReq.send().timeout(const Duration(seconds: 8));
        }

        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final data = jsonDecode(respStr) as Map<String, dynamic>;

          final success = data['success'] as bool? ?? false;
          final numWeight = ((data['detected_weight'] ?? data['numeric_weight']) as num?)?.toDouble();
          final weightStr = data['weight_string'] as String? ?? (numWeight != null ? (numWeight % 1 == 0 ? numWeight.toInt().toString() : numWeight.toString()) : null);
          final unit = (data['unit'] as String?)?.toUpperCase() ?? 'KG';
          final conf = (data['confidence'] as num?)?.toDouble() ?? 0.85;
          final rawText = (data['raw_text'] ?? data['raw_ocr_text']) as String?;
          final error = data['error'] as String?;
          final model = data['model'] as String? ?? 'RapidOCR PP-OCRv3 (ONNX)';
          final elapsed = DateTime.now().difference(t0).inMilliseconds;

          if (success && numWeight != null && numWeight > 0) {
            final sample = WeighingSample(
              weight: numWeight,
              weightString: weightStr,
              unit: unit,
              confidence: conf,
              timestamp: DateTime.now(),
              rawText: rawText,
            );
            final updatedSamples = [...existingSamples, sample];
            final stability = _evaluateStability(updatedSamples);

            return WeighingOcrResult(
              isValid: stability.isStable,
              numericWeight: numWeight,
              weightString: weightStr,
              unit: unit,
              confidence: conf,
              rawText: rawText,
              isStable: stability.isStable,
              samples: updatedSamples,
              statusMessage: stability.message,
              model: model,
              processingTimeMs: elapsed,
            );
          } else {
            return WeighingOcrResult(
              isValid: false,
              errorMessage: error ?? 'Could not detect numeric weight on weighing indicator.',
              model: model,
              processingTimeMs: elapsed,
            );
          }
        }
      } catch (e) {
        debugPrint('Remote RapidOCR endpoint unavailable, using on-device LED engine: $e');
      }
    }

    // 2. On-device high-accuracy engine (Google ML Kit + 7-segment digit parser)
    return _parseOnDevice(targetFile, existingSamples, t0);
  }

  /// On-device text recognition with 7-segment digital LED heuristics.
  /// Strict rule: NEVER invent digits or decimal points.
  static Future<WeighingOcrResult> _parseOnDevice(
    File imageFile,
    List<WeighingSample> existingSamples,
    DateTime startTime,
  ) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      await recognizer.close();

      final fullRaw = recognizedText.text;
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      // Check indicator error patterns (Baykon BX27 error states)
      final upper = fullRaw.toUpperCase();
      if (upper.contains('ERR') || upper.contains('ERROR') || upper.contains('OL') || upper.contains('OVERLOAD') || upper.contains('----')) {
        return WeighingOcrResult(
          isValid: false,
          errorMessage: 'Weighing indicator shows an error or overload state (OL / Err). Please verify scale balance.',
          rawText: fullRaw,
          model: 'On-Device 7-Segment OCR Engine',
          processingTimeMs: elapsed,
        );
      }

      // Detect unit
      String detectedUnit = 'KG';
      final unitMatch = RegExp(r'\b(kg|kgs|g|gm|t|lb)\b', caseSensitive: false).firstMatch(fullRaw);
      if (unitMatch != null) {
        final u = unitMatch.group(1)!.toUpperCase();
        if (u == 'GM' || u == 'G') {
          detectedUnit = 'G';
        } else if (u == 'LB') {
          detectedUnit = 'LB';
        } else {
          detectedUnit = 'KG';
        }
      }

      // Collect numeric candidates with bounding box prominence
      final candidates = <_NumericCandidate>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineText = line.text.trim();
          final bBox = line.boundingBox;
          final h = bBox.height.toDouble();
          final w = bBox.width.toDouble();
          final cy = bBox.center.dy;
          final cx = bBox.center.dx;

          // Strip known unit suffixes (e.g. "24 kg" -> "24")
          var clean = lineText.replaceAll(RegExp(r'\b(kg|kgs|g|gm|t|lb|lbs)\b', caseSensitive: false), '').trim();
          // Remove stray non-numeric symbols except dots and dashes
          clean = clean.replaceAll(RegExp(r'[^0-9\.\-]'), '').trim();

          // Check if clean matches a valid weight pattern
          final match = RegExp(r'^(\d{1,5}(?:\.\d{1,4})?)$').firstMatch(clean);
          if (match != null) {
            final valStr = match.group(1)!;
            final val = double.tryParse(valStr);
            if (val != null && val > 0) {
              // Confidence score based on line cleanliness
              double conf = 0.88;
              if (lineText == clean || lineText.toLowerCase().contains('kg') || lineText.toLowerCase().contains('g')) {
                conf = 0.94;
              }
              candidates.add(_NumericCandidate(
                text: valStr,
                value: val,
                height: h,
                width: w,
                yCenter: cy,
                xCenter: cx,
                confidence: conf,
              ));
            }
          } else {
            // Also inspect individual elements inside the line if line had multiple tokens
            for (final elem in line.elements) {
              var elemClean = elem.text.replaceAll(RegExp(r'\b(kg|kgs|g|gm|t|lb|lbs)\b', caseSensitive: false), '').trim();
              elemClean = elemClean.replaceAll(RegExp(r'[^0-9\.\-]'), '').trim();
              final elemMatch = RegExp(r'^(\d{1,5}(?:\.\d{1,4})?)$').firstMatch(elemClean);
              if (elemMatch != null) {
                final valStr = elemMatch.group(1)!;
                final val = double.tryParse(valStr);
                if (val != null && val > 0) {
                  final eBox = elem.boundingBox;
                  candidates.add(_NumericCandidate(
                    text: valStr,
                    value: val,
                    height: eBox.height.toDouble(),
                    width: eBox.width.toDouble(),
                    yCenter: eBox.center.dy,
                    xCenter: eBox.center.dx,
                    confidence: 0.85,
                  ));
                }
              }
            }
          }
        }
      }

      // If no candidate was found with standard recognition, check common 7-segment character confusions
      if (candidates.isEmpty) {
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final substituted = line.text
                .replaceAll(RegExp(r'[sS]'), '5')
                .replaceAll(RegExp(r'[oO]'), '0')
                .replaceAll(RegExp(r'[bB]'), '8')
                .replaceAll(RegExp(r'[zZ]'), '2')
                .replaceAll(RegExp(r'[iIlL|]'), '1')
                .replaceAll(RegExp(r'[^0-9\.]'), '')
                .trim();
            final match = RegExp(r'^(\d{1,5}(?:\.\d{1,4})?)$').firstMatch(substituted);
            if (match != null) {
              final valStr = match.group(1)!;
              final val = double.tryParse(valStr);
              if (val != null && val > 0) {
                final bBox = line.boundingBox;
                candidates.add(_NumericCandidate(
                  text: valStr,
                  value: val,
                  height: bBox.height.toDouble(),
                  width: bBox.width.toDouble(),
                  yCenter: bBox.center.dy,
                  xCenter: bBox.center.dx,
                  confidence: 0.72,
                ));
              }
            }
          }
        }
      }

      if (candidates.isEmpty) {
        return WeighingOcrResult(
          isValid: false,
          errorMessage: 'No valid positive weight digits detected on display. Position the camera closer to the LED digits and retake.',
          rawText: fullRaw,
          model: 'On-Device 7-Segment OCR Engine',
          processingTimeMs: elapsed,
        );
      }

      // Sort candidates by height descending (primary LED digits are the tallest text on the display)
      candidates.sort((a, b) => b.height.compareTo(a.height));

      final primary = candidates.first;

      // Ambiguity check: If there are multiple competing candidates with different values and comparable height
      if (candidates.length > 1) {
        final second = candidates[1];
        if (second.value != primary.value && second.height >= primary.height * 0.75) {
          // Check if they are horizontal parts of the same display line with an explicit dot
          final isSameHorizontalLine = (primary.yCenter - second.yCenter).abs() < (primary.height * 0.35);
          if (isSameHorizontalLine) {
            // Check if one part ends with dot or second part starts with dot
            final leftCandidate = primary.xCenter < second.xCenter ? primary : second;
            final rightCandidate = primary.xCenter < second.xCenter ? second : primary;

            if (leftCandidate.text.endsWith('.') || rightCandidate.text.startsWith('.')) {
              final combinedText = '${leftCandidate.text.replaceAll(".", "")}.${rightCandidate.text.replaceAll(".", "")}';
              final combinedVal = double.tryParse(combinedText);
              if (combinedVal != null && combinedVal > 0) {
                return _buildVerifiedResult(
                  weightString: combinedText,
                  numericWeight: combinedVal,
                  unit: detectedUnit,
                  confidence: 0.88,
                  rawText: fullRaw,
                  existingSamples: existingSamples,
                  elapsed: elapsed,
                );
              }
            }
          }

          // Otherwise, multiple competing large numbers exist -> AMBIGUOUS!
          return WeighingOcrResult(
            isValid: false,
            errorMessage: 'Ambiguous display reading: multiple competing numbers detected on display (${primary.text} vs ${second.text}). Align camera directly with the LED digits.',
            rawText: fullRaw,
            model: 'On-Device 7-Segment OCR Engine',
            processingTimeMs: elapsed,
          );
        }
      }

      // Single unambiguous candidate selected. Never invent decimal points!
      return _buildVerifiedResult(
        weightString: primary.text,
        numericWeight: primary.value,
        unit: detectedUnit,
        confidence: primary.confidence,
        rawText: fullRaw,
        existingSamples: existingSamples,
        elapsed: elapsed,
      );
    } catch (e) {
      return WeighingOcrResult(
        isValid: false,
        errorMessage: 'OCR Processing Error: $e. Please retake the image.',
        processingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
      );
    }
  }

  static WeighingOcrResult _buildVerifiedResult({
    required String weightString,
    required double numericWeight,
    required String unit,
    required double confidence,
    required String rawText,
    required List<WeighingSample> existingSamples,
    required int elapsed,
  }) {
    final sample = WeighingSample(
      weight: numericWeight,
      weightString: weightString,
      unit: unit,
      confidence: confidence,
      timestamp: DateTime.now(),
      rawText: rawText,
    );

    final updatedSamples = [...existingSamples, sample];
    final stability = _evaluateStability(updatedSamples);

    return WeighingOcrResult(
      isValid: stability.isStable,
      numericWeight: numericWeight,
      weightString: weightString,
      unit: unit,
      confidence: confidence,
      rawText: rawText,
      isStable: stability.isStable,
      samples: updatedSamples,
      statusMessage: stability.message,
      model: 'On-Device 7-Segment OCR Engine (ML Kit)',
      processingTimeMs: elapsed,
    );
  }

  /// Evaluate multi-sample stability policy across consecutive captured frames.
  /// Verifies if readings agree within precision tolerance (±0.005 kg).
  static ({bool isStable, String message}) _evaluateStability(List<WeighingSample> samples) {
    if (samples.isEmpty) {
      return (isStable: false, message: 'No samples captured yet.');
    }

    if (samples.length == 1) {
      final s = samples.first;
      return (
        isStable: true,
        message: 'Weight detected: ${s.displayWeight}. Single-photo verified.',
      );
    }

    // Check last 2 to 3 samples
    final recent = samples.length > 3 ? samples.sublist(samples.length - 3) : samples;
    final firstWeight = recent.first.weight;
    const tolerance = 0.005; // 5 grams tolerance for industrial scales

    for (int i = 1; i < recent.length; i++) {
      final diff = (recent[i].weight - firstWeight).abs();
      if (diff > tolerance) {
        return (
          isStable: false,
          message: 'Weight Unstable — Please Scan Again (Readings fluctuated between ${recent.first.displayWeight} and ${recent[i].displayWeight}). Wait for indicator motion to settle.',
        );
      }
    }

    return (
      isStable: true,
      message: 'Verified & Stable (${recent.length}/${recent.length} frames agreed at ${recent.first.displayWeight}).',
    );
  }
}
