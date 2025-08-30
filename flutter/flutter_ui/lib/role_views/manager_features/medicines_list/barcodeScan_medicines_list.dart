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
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  CameraFacing _currentCameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    // No manual start() call is needed here.
    // The MobileScanner widget handles it automatically.
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
        title: const Text('Scan Barcode'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
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
            print('Barcode found! $code');
            cameraController.stop();
            Navigator.of(context).pop(code);
          }
        },
      ),
    );
  }
}