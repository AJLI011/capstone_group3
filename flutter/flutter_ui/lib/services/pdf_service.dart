import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class PDFService {
  static Future<void> createAndSavePDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text("Sample PDF from Return Page!"),
        ),
      ),
    );

    try {
      // ✅ Save to app directory — NO PERMISSION NEEDED
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/return_medicine.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('PDF saved at: $filePath');
    } catch (e) {
      print('Error saving PDF: $e');
    }
  }
}
