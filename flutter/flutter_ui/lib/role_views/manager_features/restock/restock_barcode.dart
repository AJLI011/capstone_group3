// flutter_ui/lib/role_views/manager_features/restock/restock_barcode.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// IMPORTANT: No import for restock_medicine_details.dart here!

class RestockBarcodeScreen extends StatefulWidget {
  const RestockBarcodeScreen({super.key});

  @override
  State<RestockBarcodeScreen> createState() => _RestockBarcodeScreenState();
}

class _RestockBarcodeScreenState extends State<RestockBarcodeScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  CameraFacing _currentCameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    // Start the camera and update local state for torch and camera facing
    cameraController.start().then((_) {
      if (mounted) {
        setState(() {
          _isTorchOn = cameraController.torchEnabled;
          _currentCameraFacing = cameraController.facing;
        });
      }
    }).catchError((error) {
      print("Failed to start camera: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start camera: $error')),
        );
        // Optionally pop immediately if camera fails to start, or show a retry button
        Navigator.of(context).pop(); // Go back if camera fails to initialize
      }
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode (Test Mode)'), // Changed title for clarity
        elevation: 0,
        actions: [
          IconButton(
            color: Colors.white,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            iconSize: 32.0,
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() {
                _isTorchOn = cameraController.torchEnabled;
              });
            },
          ),
          IconButton(
            color: Colors.white,
            icon: Icon(
              _currentCameraFacing == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear,
            ),
            iconSize: 32.0,
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
            print('Barcode detected for testing: $code');
            cameraController.stop(); // Stop scanning

            // *** IMPORTANT: We are now just popping the barcode back for isolated testing ***
            if (mounted) {
              // Show a temporary snackbar to confirm scan before popping
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Barcode Scanned: $code (Returning to previous screen)')),
              );
              // Adding a small delay to allow snackbar to show, then pop
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) {
                  Navigator.of(context).pop(code); // Pop the scanned code back
                }
              });
            }
          }
        },
      ),
    );
  }
}