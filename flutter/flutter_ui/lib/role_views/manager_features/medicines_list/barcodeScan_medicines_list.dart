// lib/role_views/manager_features/medicines_list/barcodeScan_medicine_list.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    torchEnabled: false, // Start with torch off
    // Initial camera facing can be set here if desired, e.g., cameraFacing: CameraFacing.back,
  );

  // Local state to manage icon appearance. This is more robust.
  bool _isTorchOn = false;
  CameraFacing _currentCameraFacing = CameraFacing.back; // Assume back camera initially

  @override
  void initState() {
    super.initState();
    // It's good practice to initialize local state with the controller's actual state
    // once the controller is ready, especially for initial UI rendering.
    // The .start() call might be optional depending on when you need initial state.
    // For robust icon display on first load, we can get initial state after camera starts.
    cameraController.start().then((_) {
      if (mounted) {
        setState(() {
          _isTorchOn = cameraController.torchEnabled; // Get initial torch state
          _currentCameraFacing = cameraController.facing; // Get initial camera facing
        });
      }
    }).catchError((error) {
      // Handle camera start errors, e.g., permissions not granted
      print("Failed to start camera: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start camera: $error')),
        );
      }
    });
  }

  @override
  void dispose() {
    cameraController.dispose(); // Dispose the controller when the widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
        elevation: 0,
        actions: [
          // Flashlight button: Uses local state for icon, toggles controller
          IconButton(
            color: Colors.white,
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off, // Icon based on local state
              color: _isTorchOn ? Colors.yellow : Colors.grey,
            ),
            iconSize: 32.0,
            onPressed: () async { // Make it async because toggleTorch returns Future
              await cameraController.toggleTorch();
              setState(() {
                _isTorchOn = cameraController.torchEnabled; // Update local state from controller
              });
            },
          ),
          // Camera switch button: Uses local state for icon, switches controller
          IconButton(
            color: Colors.white,
            icon: Icon(
              _currentCameraFacing == CameraFacing.front
                  ? Icons.camera_front
                  : Icons.camera_rear, // Icon based on local state
            ),
            iconSize: 32.0,
            onPressed: () async { // Make it async because switchCamera returns Future
              await cameraController.switchCamera();
              setState(() {
                _currentCameraFacing = cameraController.facing; // Update local state from controller
              });
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        // The onDetect callback signature for v7.x.x uses a BarcodeCapture object
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
            final String code = barcodes.first.rawValue!;
            print('Barcode found! $code');
            cameraController.stop(); // Stop scanning after detection
            Navigator.of(context).pop(code); // Return the scanned code
          }
        },
      ),
    );
  }
}