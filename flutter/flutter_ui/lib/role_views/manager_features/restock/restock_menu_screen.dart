import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'restock_barcode.dart'; 
import 'restock_approval_detail_screen.dart'; 
import 'new_medicine_pr_screen.dart'; // Screen for handling unlisted items


class RestockMenuScreen extends StatefulWidget {
  const RestockMenuScreen({super.key});

  @override
  State<RestockMenuScreen> createState() => _RestockMenuScreenState();
}

class _RestockMenuScreenState extends State<RestockMenuScreen> {
  // State variables for dynamic PR ID and new item count fetching
  int? _pendingPrId; // Holds the ID of the latest pending PR
  int _unregisteredItemsCount = 0; // 🔑 NEW: Count of items missing a medicine_id
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Start fetching the ID and count when the screen loads
    _fetchLatestPendingPrId(); 
  }

  // --- Function to Fetch the Latest Pending PR ID and Unregistered Count ---
  Future<void> _fetchLatestPendingPrId() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _unregisteredItemsCount = 0; // Reset count
    });

    // NOTE: This endpoint must now return the ID and the count of unregistered items.
    const String apiUrl = 'http://10.0.2.2:8000/api/purchase-request/latest-pending/'; 
    
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // Safely extract the ID
        final int? fetchedId = data['id']; 
        // 🔑 CRITICAL: Safely extract the new count, default to 0
        final int fetchedCount = data['unregistered_new_items_count'] ?? 0;
        
        setState(() {
          _pendingPrId = (fetchedId != null && fetchedId > 0) ? fetchedId : null; 
          _unregisteredItemsCount = fetchedCount; // Store the count
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        // Backend returns 404 if no pending PR is found
        setState(() {
          _pendingPrId = null; 
          _unregisteredItemsCount = 0;
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
    // 🔑 NEW RESTRICTION: Check if all new items have been registered
    final bool allNewItemsRegistered = _unregisteredItemsCount == 0;
    
    // The Approval button is ONLY ENABLED if a PR is available AND all new items are registered.
    final bool isApprovalEnabled = isPrAvailable && !_isLoading && _errorMessage == null && allNewItemsRegistered;
    
    // Determine the button label based on the state
    String approvalButtonLabel;
    if (_isLoading) {
      approvalButtonLabel = 'Loading Pending PR...';
    } else if (_errorMessage != null) {
      approvalButtonLabel = 'Error Loading PR Status';
    } else if (!isPrAvailable) {
      approvalButtonLabel = 'Purchase Request Approval (No Pending PR)';
    } else if (!allNewItemsRegistered) {
      // New label when the button is disabled due to pending items
      approvalButtonLabel = 'Register New Items First (PR-${_pendingPrId!})'; 
    } else {
      approvalButtonLabel = 'Purchase Request Approval (PR-${_pendingPrId!})';
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

              // --- 2. Purchase Request Approval Button (Existing Medicines) ---
              ElevatedButton.icon(
                // Show different icons based on status for better UX
                icon: _isLoading 
                    ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : allNewItemsRegistered
                        ? const Icon(Icons.note_alt, size: 28) // Ready to approve
                        : const Icon(Icons.lock_outline, size: 28), // Locked icon
                label: Text(
                  approvalButtonLabel, // Use dynamic label
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  // Change color if disabled due to pending new items
                  backgroundColor: isApprovalEnabled ? primaryColor : Colors.grey, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                // 🔑 CRITICAL LOGIC: Only enable button if the comprehensive check passes
                onPressed: isApprovalEnabled
                    ? () {
                          // Use the dynamically fetched ID
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RestockApprovalDetailScreen(prId: _pendingPrId!),
                            ),
                          ).then((_) {
                              // Re-fetch the ID and count after returning from the approval screen
                              _fetchLatestPendingPrId();
                            });
                        }
                    : null, // Disable the button otherwise
              ),
              
              const SizedBox(height: 30), // Spacing for the new button

              // --- 3. New Purchased Items Button (Unlisted Items Registration) ---
              ElevatedButton.icon(
                // Show warning icon if items are pending registration
                icon: _unregisteredItemsCount > 0 
                    ? const Icon(Icons.warning_amber, color: Colors.yellow, size: 28) 
                    : const Icon(Icons.local_shipping, size: 28),
                label: Text(
                  // Show the actual number of items pending registration
                  'New Purchased Items ($_unregisteredItemsCount Pending)', 
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
                // This button is enabled if there is a pending PR
                onPressed: (isPrAvailable && !_isLoading && _errorMessage == null)
                    ? () {
                          // Navigate to the new screen to handle unlisted items
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              // Pass the pending PR ID to the new screen for context
                              builder: (context) => NewMedicinePrScreen(prId: _pendingPrId!), 
                            ),
                          ).then((result) {
                              // Refresh the PR status after returning (especially if items were registered)
                              if (result == true) {
                                _fetchLatestPendingPrId();
                              }
                            });
                        }
                    : null, // Disable if no pending PR is available
              ),
              
              // ⚠️ Conditional Warning Message
              if (!allNewItemsRegistered && isPrAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    '⚠️ You must register the $_unregisteredItemsCount new item(s) before approving PR-${_pendingPrId!}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}