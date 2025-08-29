// sales_barcode.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'sales_details.dart';

class SalesBarcodeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int? staffId;

  const SalesBarcodeScreen({
    super.key,
    required this.cartItems,
    required this.staffId,
  });

  @override
  State<SalesBarcodeScreen> createState() => _SalesBarcodeScreenState();
}

class _SalesBarcodeScreenState extends State<SalesBarcodeScreen> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isTorchOn = false;
  bool _isScanning = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isScanning) return;
    _isScanning = true;
    cameraController.stop();

    try {
      final response = await http.get(Uri.parse('http://jallybee.pythonanywhere.com/api/sales/barcode/$barcode/'));

      if (response.statusCode == 200) {
        // The API now returns a list of batches, not a single item.
        final List<dynamic> itemData = json.decode(response.body);
        if (!mounted) return;

        // Ensure there is at least one item before navigating
        if (itemData.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SalesDetailsPage(
                // Pass the entire list of batches to the next screen
                barcodeData: itemData,
                cartItems: widget.cartItems,
                staffId: widget.staffId,
              ),
            ),
          );
        } else {
          // Handle the case where the API returns an empty list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No item found for this barcode')),
          );
          Navigator.of(context).pop();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No item found for this barcode')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      Navigator.of(context).pop();
    } finally {
      _isScanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final code = capture.barcodes.first.rawValue;
          if (code != null) {
            _onBarcodeDetected(code);
          }
        },
      ),
    );
  }
}