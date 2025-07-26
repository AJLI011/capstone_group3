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
