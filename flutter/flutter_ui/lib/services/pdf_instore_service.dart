// lib/services/pdf_instore_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';

class PdfService {
  /// Saves to app internal storage, then triggers a user-visible save via FileSaver.
  /// Returns the internal app file path (good for debugging/opening later).
  static Future<String> savePdfToDownloadsAndAppStorage(
    pw.Document pdf,
    String fileName,
  ) async {
    // Build bytes
    final Uint8List pdfBytes = await pdf.save();

    // 1) Save to app documents (your own copy)
    final appDir = await getApplicationDocumentsDirectory();
    final appFilePath = p.join(appDir.path, fileName);
    await File(appFilePath).writeAsBytes(pdfBytes, flush: true);
    // print('✅ Saved to internal storage: $appFilePath');

    // 2) Let FileSaver save a copy (Android/iOS/macOS/Windows/Web)
    final baseName = p.basenameWithoutExtension(fileName);
    await FileSaver.instance.saveAs(
      name: baseName,
      bytes: pdfBytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf, // <-- correct enum
    );

    return appFilePath;
  }
}
