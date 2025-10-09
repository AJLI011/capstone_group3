//flutter\flutter_ui\lib\services\pdf_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';

class PdfService {
  /// Saves the PDF to the app's internal storage and also triggers a user-visible
  /// save to the device's downloads directory using a reliable, cross-platform method.
  static Future<String> savePdfToDownloadsAndAppStorage(
    pw.Document pdf,
    String fileName,
  ) async {
    // Build bytes from the PDF document
    final Uint8List pdfBytes = await pdf.save();

    // 1) Save a copy to the app's internal documents directory for internal use/debugging.
    final appDir = await getApplicationDocumentsDirectory();
    final appFilePath = p.join(appDir.path, fileName);
    await File(appFilePath).writeAsBytes(pdfBytes, flush: true);

    // 2) Use FileSaver to save a copy to the user's Downloads directory.
    // This is the reliable, user-friendly way to save files.
    final baseName = p.basenameWithoutExtension(fileName);
    await FileSaver.instance.saveAs(
      name: baseName,
      bytes: pdfBytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );

    return appFilePath;
  }
}
