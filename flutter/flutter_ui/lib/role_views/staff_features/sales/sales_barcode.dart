import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'sales_details.dart';
import 'order_summary.dart';
import 'package:flutter_ui/role_views/staff_view.dart';

class SalesBarcodeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const SalesBarcodeScreen({
    super.key,
    this.cartItems = const [],
  });

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
      if (mounted) {
        setState(() {
          _isTorchOn = cameraController.torchEnabled;
          _currentCameraFacing = cameraController.facing;
        });
      }
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start camera: $error')),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    cameraController.stop();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_isScanning) return;
    _isScanning = true;
    cameraController.stop();

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/sales/scan/$barcode/'),
      );

      if (response.statusCode == 200) {
        final dynamic decodedData = json.decode(response.body);

        if (decodedData is List && decodedData.isNotEmpty) {
          final Map<String, dynamic> barcodeData = decodedData.first;
          print('Barcode data fetched successfully: $barcodeData');

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SalesDetailsPage(
                  barcodeData: barcodeData,
                  cartItems: widget.cartItems,
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Not Found'),
                content: const Text('No medicine found for this barcode.'),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await cameraController.start();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // Handle the different error scenarios based on the response body
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? 'Unexpected error occurred';
        print("Error from backend: $errorMessage");

        String dialogTitle = 'Error';
        if (errorMessage.contains('does not exist')) {
          dialogTitle = 'Not Found';
        } else if (errorMessage.contains('expired')) {
          dialogTitle = 'Expired Item';
        } else if (errorMessage.contains('out of stock')) {
          dialogTitle = 'Out of Stock';
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(dialogTitle),
              content: Text(errorMessage),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await cameraController.start();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exception'),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await cameraController.start();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      _isScanning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scan for Sale'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const StaffView()),
                (Route<dynamic> route) => false,
              );
            },
          ),
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
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              final String code = barcodes.first.rawValue!;
              print('Barcode detected: $code');
              _onBarcodeDetected(code);
            }
          },
        ),
      ),
    );
  }
}