import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OcrPaymentResult
// ─────────────────────────────────────────────────────────────────────────────

/// Result of on-device OCR applied to a Yape/Plin screenshot.
/// All fields are nullable: OCR is best-effort and user can correct values.
class OcrPaymentResult {
  final String? operationId; // e.g. "123456789" or "YPE-xxxxxxx"
  final double? amount;      // e.g. 150.00 (parsed from "S/ 150.00")
  final String? rawText;     // full recognized text for debugging
  final bool    success;

  const OcrPaymentResult({
    this.operationId,
    this.amount,
    this.rawText,
    required this.success,
  });

  static const OcrPaymentResult empty = OcrPaymentResult(success: false);
}

// ─────────────────────────────────────────────────────────────────────────────
// FileService
// ─────────────────────────────────────────────────────────────────────────────

/// Handles all file operations for payment evidence:
///   • Aggressive compression to <100 KB before upload
///   • Local private backup (survives offline)
///   • On-device OCR for Yape/Plin screenshots (no server involved)
///   • Deterministic Supabase Storage path generation
///
/// All methods are static to avoid allocating service objects on every call.
/// The ML Kit recognizer is lazily initialized and reused across calls.
class FileService {
  FileService._();

  static const int    _targetSizeKb  = 100;   // upload budget in KB
  static const int    _minQuality    = 30;     // never go below this JPEG quality
  static const int    _initialQuality = 85;
  static const int    _maxDimension  = 1920;   // px — cap before compression
  static const String _localDirName  = 'payment_evidence';

  static final _uuid = const Uuid();

  // ML Kit text recognizer — reused to avoid repeated model load cost.
  // Disposed in [disposeOcr] — call once when the feature leaves the screen.
  static TextRecognizer? _recognizer;

  // ── Storage path ──────────────────────────────────────────────────────────

  /// Returns a deterministic path within the `payment_proofs` bucket.
  /// Format: `{loanId}/{transactionId}/{uuid}.jpg`
  ///
  /// Using loanId as the first segment makes Storage RLS policies clean:
  /// `storage.foldername(name)[1] = loanId`.
  static String generateStoragePath({
    required String loanId,
    String? transactionId,
  }) {
    final uid = _uuid.v4();
    return transactionId != null
        ? '$loanId/$transactionId/$uid.jpg'
        : '$loanId/$uid.jpg';
  }

  // ── Compression ───────────────────────────────────────────────────────────

  /// Compresses [source] to a JPEG file that is smaller than [_targetSizeKb].
  ///
  /// Strategy:
  ///   1. Downscale if either dimension exceeds [_maxDimension].
  ///   2. Binary-search JPEG quality between [_minQuality] and [_initialQuality]
  ///      until the result is <100 KB or quality hits the floor.
  ///
  /// Returns a new [XFile] backed by a temporary file.
  /// The caller is responsible for deleting it after upload.
  static Future<XFile> compressForUpload(XFile source) async {
    final bytes = await source.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(tempDir.path, '${_uuid.v4()}.jpg');

    int quality = _initialQuality;
    Uint8List? compressed;

    // Binary search for the highest quality that fits under the budget
    int lo = _minQuality, hi = _initialQuality;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final candidate = await FlutterImageCompress.compressWithList(
        bytes,
        quality:   mid,
        minWidth:  _maxDimension,
        minHeight: _maxDimension,
        format:    CompressFormat.jpeg,
        keepExif:  false, // strip metadata for privacy
      );

      final sizeKb = candidate.length / 1024;
      if (sizeKb <= _targetSizeKb) {
        compressed = candidate;
        quality    = mid;
        lo         = mid + 1; // try higher quality
      } else {
        hi = mid - 1; // too big — reduce quality
      }
    }

    // Fallback: if even min quality is too large, accept min quality result
    compressed ??= await FlutterImageCompress.compressWithList(
      bytes,
      quality:   _minQuality,
      minWidth:  _maxDimension,
      minHeight: _maxDimension,
      format:    CompressFormat.jpeg,
      keepExif:  false,
    );

    await File(outPath).writeAsBytes(compressed, flush: true);

    debugPrint(
      '[FileService] compressed ${_kb(bytes.length)} KB → '
      '${_kb(compressed.length)} KB (quality $quality)',
    );

    return XFile(outPath);
  }

  // ── Local persistence ─────────────────────────────────────────────────────

  /// Saves a compressed copy of [file] to the app's private directory.
  ///
  /// Path: `<appDocDir>/payment_evidence/{transactionId}.jpg`
  ///
  /// This backup is invisible to the device gallery and survives app restarts,
  /// so the debtor always has their proof even without network.
  static Future<File> saveLocalCopy(XFile file, String transactionId) async {
    final dir = await _localEvidenceDir();
    final dest = File(p.join(dir.path, '$transactionId.jpg'));
    final bytes = await file.readAsBytes();
    await dest.writeAsBytes(bytes, flush: true);
    debugPrint('[FileService] local copy saved → ${dest.path}');
    return dest;
  }

  /// Returns the local backup file for [transactionId], or null if not found.
  static Future<File?> getLocalCopy(String transactionId) async {
    final dir  = await _localEvidenceDir();
    final file = File(p.join(dir.path, '$transactionId.jpg'));
    return file.existsSync() ? file : null;
  }

  /// Deletes the local backup for [transactionId] once the upload is confirmed.
  static Future<void> deleteLocalCopy(String transactionId) async {
    final dir  = await _localEvidenceDir();
    final file = File(p.join(dir.path, '$transactionId.jpg'));
    if (file.existsSync()) {
      await file.delete();
      debugPrint('[FileService] local copy deleted → ${file.path}');
    }
  }

  // ── OCR ───────────────────────────────────────────────────────────────────

  /// Runs on-device OCR on [imageFile] and attempts to extract the payment
  /// amount and operation ID from Yape / Plin screenshots.
  ///
  /// Processing is fully local — no data leaves the device.
  /// The ML Kit model is downloaded once and cached on the device.
  static Future<OcrPaymentResult> extractPaymentInfo(XFile imageFile) async {
    try {
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognized = await _recognizer!.processImage(inputImage);
      final rawText    = recognized.text;

      final operationId = _extractOperationId(rawText);
      final amount      = _extractAmount(rawText);

      debugPrint('[FileService] OCR raw: $rawText');
      debugPrint('[FileService] OCR → operationId=$operationId, amount=$amount');

      return OcrPaymentResult(
        operationId: operationId,
        amount:      amount,
        rawText:     rawText,
        success:     operationId != null || amount != null,
      );
    } catch (e) {
      debugPrint('[FileService] OCR error: $e');
      return OcrPaymentResult.empty;
    }
  }

  /// Releases the ML Kit recognizer when it's no longer needed.
  /// Call this in the `dispose()` of the screen that uses OCR.
  static Future<void> disposeOcr() async {
    await _recognizer?.close();
    _recognizer = null;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  static Future<Directory> _localEvidenceDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir    = Directory(p.join(appDir.path, _localDirName));
    if (!dir.existsSync()) { await dir.create(recursive: true); }
    return dir;
  }

  static String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);

  // ── OCR pattern matching ──────────────────────────────────────────────────

  // Amount patterns: "S/ 150.00", "S/150", "S/. 1,500.00"
  static final _amountRegex = RegExp(
    r'S/\.?\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  // Operation ID patterns (Yape/Plin use numeric strings of 9–15 digits,
  // optionally prefixed with "N°", "Nro", "#", "Operación", "Op.")
  static final _operationIdRegex = RegExp(
    r'(?:N[°º]\.?|Nro\.?|#|[Oo]p(?:eración|\.)?)\s*:?\s*([A-Z0-9]{8,20})',
    caseSensitive: false,
  );

  // Fallback: a standalone 9-15 digit sequence that looks like an op number
  static final _fallbackOpIdRegex = RegExp(r'\b(\d{9,15})\b');

  static String? _extractOperationId(String text) {
    final match = _operationIdRegex.firstMatch(text);
    if (match != null) { return match.group(1)?.trim(); }

    // Fallback: pick the first long numeric sequence not matching amount pattern
    for (final m in _fallbackOpIdRegex.allMatches(text)) {
      final candidate = m.group(1)!;
      // Exclude amounts (≤ 6 digits with decimals handled by amountRegex)
      if (candidate.length >= 9) { return candidate; }
    }
    return null;
  }

  static double? _extractAmount(String text) {
    final match = _amountRegex.firstMatch(text);
    if (match == null) { return null; }

    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convenience extension on XFile
// ─────────────────────────────────────────────────────────────────────────────

extension XFileSize on XFile {
  Future<int> get sizeInBytes async {
    final f = File(path);
    return f.existsSync() ? await f.length() : 0;
  }

  Future<double> get sizeInKb async => (await sizeInBytes) / 1024;
  Future<double> get sizeInMb async => (await sizeInBytes) / (1024 * 1024);
}
