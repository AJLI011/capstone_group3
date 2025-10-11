import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// NOTE: Ensure this base URL matches the IP address you used in Postman!
const String _baseUrl = 'http://192.168.0.104:8000/api'; 

// --------------------------------------------------------------------------
// 1. Data Models (Mirroring the JSON structure you confirmed)
// --------------------------------------------------------------------------

class ReturnVerificationImage {
  final int id;
  final String imageUrl; 

  ReturnVerificationImage({required this.id, required this.imageUrl});

  factory ReturnVerificationImage.fromJson(Map<String, dynamic> json) {
    return ReturnVerificationImage(
      id: json['id'] as int,
      imageUrl: json['image'] as String,
    );
  }
}

class ReturnedMedicine {
  final int id;
  final String medicineName;
  final String batchNum;
  final String expDate;
  final int quantity;

  ReturnedMedicine({
    required this.id,
    required this.medicineName,
    required this.batchNum,
    required this.expDate,
    required this.quantity,
  });

  factory ReturnedMedicine.fromJson(Map<String, dynamic> json) {
    // Access nested medicine name: "medicine": { "name": "..." }
    final medicineData = json['medicine'] as Map<String, dynamic>?; 
    
    // CRITICAL CHANGE 1: Use medicine_name_snapshot as fallback
    final String resolvedMedicineName = (medicineData != null ? medicineData['name'] as String? : null) ??
                                        (json['medicine_name_snapshot'] as String?) ?? // Fallback to snapshot
                                        'N/A';

    return ReturnedMedicine(
      id: json['id'] as int,
      medicineName: resolvedMedicineName,
      batchNum: json['batch_num'] ?? 'N/A',
      expDate: json['exp_date'] ?? 'N/A',
      quantity: json['quantity'] ?? 0,
    );
  }
}

class ReturnTransaction {
  final int id;
  final String staffName;
  final DateTime returnedAt;
  final String status;
  final String? notes;
  final List<ReturnedMedicine> returnedItems;
  final List<ReturnVerificationImage> verificationImages;

  ReturnTransaction({
    required this.id,
    required this.staffName,
    required this.returnedAt,
    required this.status,
    this.notes,
    required this.returnedItems,
    required this.verificationImages,
  });

  factory ReturnTransaction.fromJson(Map<String, dynamic> json) {
    // Access nested staff name: "staff": { "name": "..." }
    final staffData = json['staff'] as Map<String, dynamic>?;
    
    // CRITICAL CHANGE 2: Use staff_name_snapshot as fallback
    final String resolvedStaffName = (staffData != null ? staffData['name'] as String? : null) ??
                                     (json['staff_name_snapshot'] as String?) ?? // Fallback to snapshot
                                     'N/A';
    
    // Parse nested lists
    final itemsList = json['returned_items'] as List<dynamic>? ?? [];
    final imagesList = json['verification_images'] as List<dynamic>? ?? [];

    return ReturnTransaction(
      id: json['id'] as int,
      staffName: resolvedStaffName,
      returnedAt: DateTime.parse(json['returned_at']),
      status: json['verification_status'] ?? 'PENDING',
      notes: json['notes'],
      returnedItems: itemsList.map((i) => ReturnedMedicine.fromJson(i)).toList(),
      verificationImages: imagesList.map((i) => ReturnVerificationImage.fromJson(i)).toList(),
    );
  }
}

// --------------------------------------------------------------------------
// 2. Main View Widget
// --------------------------------------------------------------------------

class ReturnViewPage extends StatefulWidget {
  const ReturnViewPage({super.key});

  @override
  State<ReturnViewPage> createState() => _ReturnViewPageState();
}

class _ReturnViewPageState extends State<ReturnViewPage> {
  List<ReturnTransaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  // --------------------------------------------------------------------------
  // API Call: Fetch All Return Transactions (using /returns/all/ endpoint)
  // --------------------------------------------------------------------------
  Future<void> _fetchTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('$_baseUrl/returns/all/'));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _transactions = data
              .map((json) => ReturnTransaction.fromJson(json))
              .toList();
        });
      } else {
        if (mounted) {
          _showSnackBar('Failed to load transactions. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error fetching transactions: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // --------------------------------------------------------------------------
  // Helper: Status Display
  // --------------------------------------------------------------------------
  Color _getStatusColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      case 'PENDING':
      default:
        return Colors.orange.shade700;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'VERIFIED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'PENDING':
      default:
        return Icons.pending_actions;
    }
  }

  // --------------------------------------------------------------------------
  // 3. Build Method
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Medicines'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchTransactions,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No Return Transactions Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: _fetchTransactions, child: const Text('Try Refreshing')),
                    ],
                  ),
                )
              : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12.0),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final txn = _transactions[index];
                        return _buildTransactionCard(txn);
                      },
                    ),
                  ),
    );
  }

  // --------------------------------------------------------------------------
  // 4. Widget Builder: Transaction Card
  // --------------------------------------------------------------------------
  Widget _buildTransactionCard(ReturnTransaction txn) {
    final statusColor = _getStatusColor(txn.status);
    final statusIcon = _getStatusIcon(txn.status);
    final formattedDate = DateFormat('MMM d, yyyy h:mm a').format(txn.returnedAt.toLocal()); // Use toLocal() for better time display

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        collapsedBackgroundColor: Colors.grey.shade50,
        backgroundColor: Colors.white,
        leading: Icon(statusIcon, color: statusColor, size: 30),
        // txn.staffName now safely uses snapshot data if original staff is deleted
        title: Text(
          'Txn ID: ${txn.id} - ${txn.staffName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returned: $formattedDate', style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Text(
                  'Status: ${txn.status}',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
                if (txn.verificationImages.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.photo_library, size: 16, color: Colors.blue.shade700, semanticLabel: 'Images Attached'),
                ]
              ],
            ),
          ],
        ),
        
        // Detailed Content when Expanded
        children: <Widget>[
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildReturnedItemsSection(txn.returnedItems),
          
          if (txn.verificationImages.isNotEmpty) 
            _buildVerificationImagesSection(txn.verificationImages),

          if (txn.notes != null && txn.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(txn.notes!),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 5. Widget Builder: Returned Items List
  // --------------------------------------------------------------------------
  Widget _buildReturnedItemsSection(List<ReturnedMedicine> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No returned medicine items recorded for this transaction.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Returned Items Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // item.medicineName now safely uses snapshot data if original medicine is deleted
                      Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('Batch: ${item.batchNum} | Exp: ${item.expDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 6. Widget Builder: Verification Images
  // --------------------------------------------------------------------------
  Widget _buildVerificationImagesSection(List<ReturnVerificationImage> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Verification Images:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        SizedBox(
          height: 120, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, image.imageUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      image.imageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      // Error and Loading builders are essential for network images
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.red.shade100,
                          child: const Center(
                            child: Icon(Icons.error, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 7. Utility: Image Viewer Dialog (MODIFIED for full-screen viewing)
  // --------------------------------------------------------------------------
    void _showImageDialog(BuildContext context, String imageUrl) {
      // Instead of showDialog, navigate to a new screen for full-screen view
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullImageScreen(imageUrl: imageUrl),
        ),
      );
    }
  } // End of _ReturnViewPageState

  // --------------------------------------------------------------------------
  // NEW: Full-Screen Image Viewer Widget
  // --------------------------------------------------------------------------

  class FullImageScreen extends StatelessWidget {
    final String imageUrl;

    const FullImageScreen({super.key, required this.imageUrl});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black, // Dark background for better image focus
        // --- REMOVED: AppBar(title: const Text('Verification Image'), ...) ---
        body: Center(
          // InteractiveViewer allows the user to pinch-to-zoom and pan the image
          child: InteractiveViewer(
            panEnabled: true, // Allows dragging the image
            minScale: 0.1,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain, // Fits the image within the screen without cropping
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Error loading image. Check network and file path.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }