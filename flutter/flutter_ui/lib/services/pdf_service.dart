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

/* OLD VERSION
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

Future<void> savePdfToDownloads(pw.Document pdf) async {
  // Ask permission first
  final status = await Permission.manageExternalStorage.request();
  if (!status.isGranted) {
    print('Permission denied');
    return;
  }

  // Define the Downloads directory manually
  final downloadsDir = Directory('/storage/emulated/0/Download');
  if (!await downloadsDir.exists()) {
    print('Downloads folder not found');
    return;
  }

  final filePath = path.join(downloadsDir.path, 'returned_medicines_report.pdf');
  final file = File(filePath);

  try {
    await file.writeAsBytes(await pdf.save());
    print('✅ PDF saved at: $filePath');
  } catch (e) {
    print('❌ Error saving PDF: $e');
  }
}
*/