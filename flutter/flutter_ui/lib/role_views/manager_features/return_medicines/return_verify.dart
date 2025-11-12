import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 1. IMPORT THE FILE WITH THE PDF FUNCTION
import 'return_page.dart';

// --- NEW TIMEZONE IMPORTS ---
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
// ----------------------------

// NOTE: Please replace with your actual server IP
const String _baseUrl = 'http://192.168.1.12:8000/api';

// --------------------------------------------------------------------------
// Data Model for Returned Item (Item in a Transaction)
// --------------------------------------------------------------------------
class ReturnedItem {
  final int id;
  final String medicineName;
  final String batchNum;
  final int quantity;
  final String expDate;
  final String supplierName;

  ReturnedItem({
    required this.id,
    required this.medicineName,
    required this.batchNum,
    required this.quantity,
    required this.expDate,
    this.supplierName = 'N/A', 
  });

  // Conversion method for PDF generation
  Map<String, dynamic> toPdfMap() {
    return {
      'id': id,
      'medicine_name': medicineName,
      'batch_num': batchNum,
      'quantity': quantity,
      'exp_date': expDate,
      'supplier_name': supplierName,
    };
  }

  factory ReturnedItem.fromJson(Map<String, dynamic> json) {
    // CRITICAL CHANGE 1: Use medicine_name_snapshot as a fallback for medicineName
    final String resolvedMedicineName = (json['medicine_name'] as String?) ??
                                        (json['medicine_name_snapshot'] as String?) ??
                                        'Unknown Medicine';

    return ReturnedItem(
      id: json['id'] as int,
      medicineName: resolvedMedicineName,
      batchNum: json['batch_num'] ?? 'N/A',
      quantity: json['quantity'] ?? 0,
      expDate: json['exp_date'] ?? 'N/A', 
      supplierName: json['supplier_name'] ?? 'N/A', // Assuming supplier name is directly available or null/N/A
    );
  }
}

// --------------------------------------------------------------------------
// Data Model for a Pending Transaction (Item in the List)
// UPDATED: Use DateTime object for returnedAt and explicitly set it to UTC
// --------------------------------------------------------------------------
class PendingTransaction {
  final int id;
  final String staffName;
  final DateTime returnedAt; // Changed from String to DateTime

  PendingTransaction({
    required this.id,
    required this.staffName,
    required this.returnedAt,
  });

  factory PendingTransaction.fromJson(Map<String, dynamic> json) {
    // CRITICAL CHANGE 2: Use staff_name_snapshot as a fallback for staffName
    final String resolvedStaffName = (json['staff_name'] as String?) ??
                                     (json['staff_name_snapshot'] as String?) ??
                                     'Unknown Staff';
    
    // CRITICAL CHANGE 3: Convert the returned_at string from the database to a UTC DateTime
    DateTime parsedReturnedAt;
    try {
        parsedReturnedAt = DateTime.parse(json['returned_at']).toUtc();
    } catch (e) {
        // Fallback for null or invalid date string
        parsedReturnedAt = DateTime.now().toUtc(); 
    }

    return PendingTransaction(
      id: json['id'] as int,
      staffName: resolvedStaffName,
      returnedAt: parsedReturnedAt, // Use the new DateTime object
    );
  }
}

// --------------------------------------------------------------------------
// Return Verification Page (Main State Controller)
// --------------------------------------------------------------------------
class ReturnVerificationPage extends StatefulWidget {
  const ReturnVerificationPage({super.key});

  @override
  State<ReturnVerificationPage> createState() => _ReturnVerificationPageState();
}

class _ReturnVerificationPageState extends State<ReturnVerificationPage> {
  // 1. State for Selection
  List<PendingTransaction> _pendingTransactions = [];
  bool _isTransactionsLoading = false;

  // 2. State for Verification
  PendingTransaction? _selectedTransaction;
  List<ReturnedItem> _transactionItems = [];
  bool _isItemsLoading = false;
  
  // 3. State for Upload
  final List<XFile> _verificationImages = [];
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Start by fetching the list of pending transactions
    _fetchPendingTransactions();
  }
  
  // -----------------------------------------------------------------------
  // Timezone Helper Function: Format UTC DateTime to Manila Timezone String
  // -----------------------------------------------------------------------
  String _formatManilaTime(DateTime utcTime) {
    // 1. Get the Asia/Manila location
    final location = tz.getLocation('Asia/Manila');

    // 2. Convert the UTC DateTime to a TimeZone-aware DateTime in Manila
    final manilaTime = tz.TZDateTime.from(utcTime, location);

    // 3. Format the Manila time
    // Example format: Oct 11, 2025 02:07 PM
    return DateFormat('MMM dd, yyyy hh:mm a').format(manilaTime);
  }

  // -----------------------------------------------------------------------
  // API Call: Fetch List of Pending Transactions
  // -----------------------------------------------------------------------
  Future<void> _fetchPendingTransactions() async {
    if (!mounted) return;
    setState(() => _isTransactionsLoading = true);

    try {
      final response = await http.get(Uri.parse('$_baseUrl/returns/pending/'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _pendingTransactions = data
              .map((json) => PendingTransaction.fromJson(json))
              .toList();
        });
      } else {
          if (mounted) _showSnackBar('Failed to load pending returns. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error fetching pending transactions: $e');
    } finally {
      if (mounted) setState(() => _isTransactionsLoading = false);
    }
  }

  // -----------------------------------------------------------------------
  // API Call: Fetch Items for Selected Transaction
  // -----------------------------------------------------------------------
  Future<void> _fetchTransactionItems(PendingTransaction transaction) async {
    if (!mounted) return;
    setState(() {
      _selectedTransaction = transaction;
      _isItemsLoading = true;
      _transactionItems = []; // Clear previous items
      _verificationImages.clear(); // Clear previous images
    });

    try {
      final url = '$_baseUrl/returns/${transaction.id}/items/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _transactionItems = data.map((json) => ReturnedItem.fromJson(json)).toList();
        });
      } else {
        if (mounted) _showSnackBar('Failed to load items. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error fetching transaction items: $e');
    } finally {
      if (mounted) setState(() => _isItemsLoading = false);
    }
  }

  // -----------------------------------------------------------------------
  // PDF Generation Trigger
  // -----------------------------------------------------------------------
  void _generateReport() {
    if (_selectedTransaction == null || _transactionItems.isEmpty) {
      _showSnackBar('Cannot generate report: No transaction selected or no items loaded.');
      return;
    }

    // Convert the List<ReturnedItem> to List<Map<String, dynamic>>
    final List<Map<String, dynamic>> pdfData = 
        _transactionItems.map((item) => item.toPdfMap()).toList();

    // Call the shared function from return_page.dart
    generateAndSavePdf(context, pdfData);
  }


  // -----------------------------------------------------------------------
  // Image Capture/Selection Logic
  // -----------------------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80, // Optimize file size
    );

    if (image != null) {
      setState(() {
        _verificationImages.add(image);
      });
    }
  }
  
  // -----------------------------------------------------------------------
  // API Call: Upload Images and Finalize Verification
  // -----------------------------------------------------------------------
  Future<void> _uploadImages() async {
    if (_selectedTransaction == null || _verificationImages.isEmpty) {
      _showSnackBar('Please select a transaction and capture at least one image.');
      return;
    }
    
    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getInt('staff_id');

      if (staffId == null) {
        throw Exception('Staff ID not found. Cannot upload.');
      }
      
      final uploadUrl = Uri.parse('$_baseUrl/returns/upload-verification/');
      final request = http.MultipartRequest('POST', uploadUrl);

      // Add fields
      request.fields['transaction_id'] = _selectedTransaction!.id.toString();
      request.fields['staff_id'] = staffId.toString(); // Include staff_id 

      // Add image files
      for (var image in _verificationImages) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'verification_images', // MUST match Django key
            image.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (mounted) {
            _showSnackBar(responseData['message'] ?? 'Verification successful! Transaction set to VERIFIED.');
        }
        
        // Reset state after success
        setState(() {
          _selectedTransaction = null;
          _transactionItems = [];
          _verificationImages.clear();
          _isUploading = false;
        });
        
        // Refresh the list of pending transactions
        _fetchPendingTransactions();
        
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Upload Error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  // -----------------------------------------------------------------------
  // BUILD METHOD (Handles State Display)
  // -----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Determine which view to show based on whether a transaction is selected
    if (_selectedTransaction == null) {
      return _buildTransactionSelectionView();
    } else {
      return _buildVerificationUploadView();
    }
  }

  // -----------------------------------------------------------------------
  // UI 1: Transaction Selection View (List of PENDING Transactions)
  // -----------------------------------------------------------------------
  Widget _buildTransactionSelectionView() {
    if (_isTransactionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'No Pending Returns',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All returned items have been verified.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            TextButton(
              onPressed: _fetchPendingTransactions,
              child: const Text('Refresh List'),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Pending Return Verification',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: RefreshIndicator( // Allow pull-to-refresh
            onRefresh: _fetchPendingTransactions,
            child: ListView.builder(
              itemCount: _pendingTransactions.length,
              itemBuilder: (context, index) {
                final txn = _pendingTransactions[index];
                return ListTile(
                  leading: const Icon(Icons.pending_actions, color: Colors.orange),
                  // txn.staffName now safely contains snapshot data if needed
                  title: Text('Transaction ID: ${txn.id} - ${txn.staffName}'),
                  // CRITICAL CHANGE: Use the format function here
                  subtitle: Text('Returned At: ${_formatManilaTime(txn.returnedAt)}'), 
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _fetchTransactionItems(txn),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------------
  // UI 2: Verification and Upload View (Display Items and Capture Images)
  // -----------------------------------------------------------------------
  Widget _buildVerificationUploadView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Back Button
              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Transactions'),
                onPressed: () {
                  setState(() {
                    _selectedTransaction = null;
                    _verificationImages.clear();
                  });
                },
              ),
            ],
          ),
          
          // Transaction Header
          Text(
            'Verify Return Transaction ID: ${_selectedTransaction!.id}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            // CRITICAL CHANGE: Use the format function here
            'Staff: ${_selectedTransaction!.staffName} | Date: ${_formatManilaTime(_selectedTransaction!.returnedAt)}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const Divider(),
          
          // List of Items to Verify
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Items for Verification:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          _isItemsLoading
              ? const Center(child: CircularProgressIndicator())
              : _transactionItems.isEmpty
                  ? const Text('No items found for this transaction.', style: TextStyle(color: Colors.red))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactionItems.length,
                      itemBuilder: (context, index) {
                        final item = _transactionItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                            // item.medicineName now safely contains snapshot data if needed
                            title: Text(item.medicineName), 
                            subtitle: Text('Batch: ${item.batchNum} | Exp: ${item.expDate}'),
                          ),
                        );
                      },
                    ),
          
          const SizedBox(height: 20),
          
          // Image Capture Section
          const Text(
            'Verification Photos (Minimum 1 Required):',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          
          // Image Grid
          Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              // Add/Camera button
              _buildImageCaptureButton(),
              // Display captured images
              ..._verificationImages.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(file.path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _verificationImages.removeAt(index);
                          });
                        },
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // NEW PDF BUTTON LOCATION
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isItemsLoading || _transactionItems.isEmpty ? null : _generateReport,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate Return Report PDF'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700),
              ),
            ),
          ),

          const SizedBox(height: 10), // Small separator
          
          // Upload Button (Finalize Verification)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploading || _isItemsLoading || _verificationImages.isEmpty
                  ? null
                  : _uploadImages,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20, height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Finalize Verification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helper Widget: Image Capture Button
  // -----------------------------------------------------------------------
  Widget _buildImageCaptureButton() {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
            Text('Add Photo', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}