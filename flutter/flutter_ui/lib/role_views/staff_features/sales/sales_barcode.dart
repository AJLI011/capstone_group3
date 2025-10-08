import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
// Assuming this is still used for context, but not directly in the navigation logic here
import 'batch_selection.dart'; // Import the new BatchSelectionPage

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
  // 1. Initialize the MobileScannerController
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false,
    autoStart: true, // Default, but good to be explicit
  );
  
  bool _isTorchOn = false;
  CameraFacing _currentCameraFacing = CameraFacing.back;
  // Flag to prevent multiple concurrent detection calls
  bool _isScanning = false; 

  // 2. Dispose of the controller when the screen is permanently removed
  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  // 3. Central logic for barcode detection and navigation
  Future<void> _onBarcodeDetected(String barcode) async {
    // Prevent multiple calls while processing
    if (_isScanning) return;
    _isScanning = true;

    // Stop the camera feed immediately upon detection 
    // to prevent continuous scanning during API call/navigation
    cameraController.stop(); 

    try {
      final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/sales/barcode/$barcode/'));

      if (response.statusCode == 200) {
        final List<dynamic> itemData = json.decode(response.body);
        if (!mounted) return;

        if (itemData.isNotEmpty) {
          // Navigate to BatchSelectionPage
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BatchSelectionPage(
                batches: itemData,
                staffId: widget.staffId,
              ),
            ),
          ).then((_) {
            // FIX: This .then() block runs when the user navigates back (pops) 
            // from the BatchSelectionPage.
            if (mounted) {
              // Explicitly restart the camera
              cameraController.start(); 
              _isScanning = false; // Reset the flag
            }
          });
          return; // Exit here as navigation is handled
        } else {
          // No item found, inform user and restart scanner
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No item found for this barcode')),
          );
        }
      } else {
        // API call failed, inform user and restart scanner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No item found for this barcode')),
        );
      }
    } catch (e) {
      // General error (e.g., network issue), inform user and restart scanner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } 
    
    // If we reach this point, it means no navigation occurred (API fail, no data)
    // so we restart the camera and reset the scanning flag to allow a new scan attempt.
    cameraController.start();
    _isScanning = false;
  }

  // 4. Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF5C7C9A), 
        foregroundColor: Colors.white, 
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() => _isTorchOn = cameraController.torchEnabled);
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
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            final String code = barcodes.first.rawValue!;
            _onBarcodeDetected(code);
          }
        },
      ),
    );
  }
}