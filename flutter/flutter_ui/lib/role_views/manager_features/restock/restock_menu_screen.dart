import 'package:flutter/material.dart';
import 'restock_barcode.dart'; // Import the original scanner screen name

class RestockMenuScreen extends StatelessWidget {
  const RestockMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C7C9A); // Your theme color

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restock Options'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- 1. Scan Barcode Button ---
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text(
                  'Scan Barcode',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () async {
                  // Navigate to the existing scanner screen (RestockBarcodeScreen)
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RestockBarcodeScreen(),
                    ),
                  );
                  
                  // If scanning was successful, pop the menu screen as well.
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
              
              const SizedBox(height: 30), // Spacer

              // --- 2. Purchase Request Approval Button ---
              ElevatedButton.icon(
                icon: const Icon(Icons.note_alt, size: 28),
                label: const Text(
                  'Purchase Request Approval',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  // Placeholder action
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Future Feature: Purchase Request Approval')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}