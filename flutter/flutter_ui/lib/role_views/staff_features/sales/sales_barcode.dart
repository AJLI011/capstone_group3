import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'sales_details.dart'; // This is your full SalesDetailsPage

class SalesBarcodeScreen extends StatefulWidget {
  final int staffId;

  const SalesBarcodeScreen({super.key, required this.staffId});

  @override
  State<SalesBarcodeScreen> createState() => _SalesBarcodeScreenState();
}

class _SalesBarcodeScreenState extends State<SalesBarcodeScreen> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  CameraFacing _currentCameraFacing = CameraFacing.back;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    cameraController.start().then((_) {
      setState(() {
        _isTorchOn = cameraController.torchEnabled;
        _currentCameraFacing = cameraController.facing;
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start camera: $error')),
      );
      Navigator.of(context).pop();
    });
  }

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
      final url = 'http://10.0.2.2:8000/api/sales/barcode/$barcode/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final itemData = json.decode(response.body);
        print('Scanned item data: ${jsonEncode(itemData)}');

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SalesDetailsPage(
                barcodeData: itemData,
                staffId: widget.staffId,
                cartItems: [], // Empty cart for now
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No item found for this barcode')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      _isScanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode for Sale'),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() {
                _isTorchOn = cameraController.torchEnabled;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _currentCameraFacing == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear,
            ),
            onPressed: () async {
              await cameraController.switchCamera();
              setState(() {
                _currentCameraFacing = cameraController.facing;
              });
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            final String code = barcodes.first.rawValue!;
            print('Barcode detected: $code');
            _onBarcodeDetected(code);
          }
        },
      ),
    );
  }
}
