// lib/restock_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // New import for HTTP
import 'dart:convert'; // New import for JSON decoding
import 'restock_barcode.dart'; 
import 'restock_approval_detail_screen.dart'; 

// IMPORTANT: Convert StatelessWidget to StatefulWidget
class RestockMenuScreen extends StatefulWidget {
  const RestockMenuScreen({super.key});

  @override
  State<RestockMenuScreen> createState() => _RestockMenuScreenState();
}

class _RestockMenuScreenState extends State<RestockMenuScreen> {
  // State variables for dynamic PR ID fetching
  int? _pendingPrId; // Holds the ID of the latest pending PR
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start fetching the ID of the pending PR when the screen loads
    _fetchLatestPendingPrId(); 
  }

  // --- NEW: Function to Fetch the Latest Pending PR ID ---
  Future<void> _fetchLatestPendingPrId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // NOTE: This endpoint needs to be implemented in your Django backend.
    // It should return the ID of the latest PurchaseRequest with status='PENDING'.
    const String apiUrl = 'http://192.168.1.12:8000/api/purchase-request/latest-pending/'; 
    
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final int? fetchedId = data['id'];
        
        setState(() {
          _pendingPrId = fetchedId; // Will be null if Django returns {id: null} or {}
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // Backend returns 404 if no pending PR is found
        setState(() {
          _pendingPrId = null; 
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load pending PR status: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF5C7C9A); 
    
    // Check if a pending PR ID was successfully fetched
    final bool isPrAvailable = _pendingPrId != null && _pendingPrId! > 0;
    
    // Determine the button label based on the state
    String approvalButtonLabel;
    if (_isLoading) {
      approvalButtonLabel = 'Loading Pending PR...';
    } else if (_errorMessage != null) {
      approvalButtonLabel = 'Error Loading PR Status';
    } else if (isPrAvailable) {
      approvalButtonLabel = 'Purchase Request Approval (PR-${_pendingPrId!})';
    } else {
      approvalButtonLabel = 'Purchase Request Approval (No Pending PR)';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restock Options'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Add a refresh button to manually check for new PRs
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchLatestPendingPrId,
            tooltip: 'Refresh Pending PR Status',
          ),
        ],
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
                  // --- MODIFIED FONT SIZE ---
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), 
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
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const RestockBarcodeScreen(),
                    ),
                  );
                  
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
              
              const SizedBox(height: 30), 

              // --- 2. Purchase Request Approval Button (FIXED DYNAMIC ID) ---
              ElevatedButton.icon(
                // Show a loading indicator in the icon slot if loading
                icon: _isLoading 
                    ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.note_alt, size: 28),
                label: Text(
                  approvalButtonLabel, // Use dynamic label
                  // --- MODIFIED FONT SIZE ---
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                // Only enable button if not loading AND a PR is available
                onPressed: (isPrAvailable && !_isLoading && _errorMessage == null)
                    ? () {
                          // Use the dynamically fetched ID
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RestockApprovalDetailScreen(prId: _pendingPrId!),
                            ),
                          ).then((_) {
                              // Re-fetch the ID after returning from the approval screen
                              _fetchLatestPendingPrId();
                          });
                        }
                    : null, // Disable the button otherwise
              ),
            ],
          ),
        ),
      ),
    );
  }
}