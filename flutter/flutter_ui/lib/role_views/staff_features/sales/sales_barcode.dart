// sales_barcode.dart
import 'dart:convert';
import 'package:flutter/material.dart';
// NOTE: Make sure your pubspec.yaml version of mobile_scanner supports this API.
// The MobileScanner.overlay property was removed in later versions.
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

// Import the next screen in the flow
import 'batch_selection.dart'; 

class SalesBarcodeScreen extends StatefulWidget {
  // Existing cart items are passed here
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
    autoStart: true,
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
    cameraController.stop(); 

    try {
      final response = await http.get(Uri.parse('http://192.168.1.20:8000/api/sales/barcode/$barcode/'));

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
                // --- CRITICAL LINE FOR MULTI-ORDER SUPPORT ---
                // Pass the current cart items to the next step
                existingCartItems: widget.cartItems, 
              ),
            ),
          ).then((result) {
            // This runs when BatchSelectionPage (or a subsequent page) is popped.
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
            const SnackBar(content: Text('No inventory/batches found for this barcode')),
          );
        }
      } else {
        // API call failed, inform user and restart scanner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch item data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // General error (e.g., network issue), inform user and restart scanner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network Error: $e')));
    } 
    
    // If we reach this point, it means no navigation occurred (API fail, no data)
    // so we restart the camera and reset the scanning flag to allow a new scan attempt.
    if (mounted) {
      cameraController.start();
      _isScanning = false;
    }
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
              // Ensure the controller is active before toggling torch
              if (cameraController.value.isInitialized) {
                await cameraController.toggleTorch();
                setState(() => _isTorchOn = cameraController.torchEnabled);
              }
            },
          ),
          IconButton(
            icon: Icon(
              _currentCameraFacing == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear,
            ),
            onPressed: () async {
              // Ensure the controller is active before switching camera
              if (cameraController.value.isInitialized) {
                await cameraController.switchCamera();
                setState(() {
                  _currentCameraFacing = cameraController.facing;
                });
              }
            },
          ),
        ],
      ),
      // --- FIX: Replace MobileScanner with overlay property with Stack ---
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final String code = barcodes.first.rawValue!;
                _onBarcodeDetected(code);
              }
            },
          ),
          // --- Custom Overlay Layer (White outline/box) REMOVED ---
          // --- Text instruction overlay (Point the camera at the barcode) REMOVED ---
        ],
      ),
    );
  }
}