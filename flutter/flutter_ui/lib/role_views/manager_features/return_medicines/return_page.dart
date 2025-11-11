// return_page.dart (UPDATED)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ui/services/pdf_service.dart';

// Import for Timezone initialization
import 'package:timezone/data/latest.dart' as tzdata; 
import 'package:timezone/timezone.dart' as tz; 

// Import the verification page
import 'return_verify.dart'; // Ensure this file is correct

// NEW: Import the Return View Tab
import 'return_view.dart'; // Ensure this new file is correct

// NOTE: Please replace with your actual server IP
const String _baseUrl = '10.0.2.2:8000/api';

// --------------------------------------------------------------------------
// 1. New Parent Widget to Handle Tabs (NOW STATEFUL FOR TIMEZONE INIT)
// --------------------------------------------------------------------------
class ReturnMedicinePage extends StatefulWidget {
  const ReturnMedicinePage({super.key});

  @override
  State<ReturnMedicinePage> createState() => _ReturnMedicinePageState();
}

class _ReturnMedicinePageState extends State<ReturnMedicinePage> {
  bool _isTimezoneInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
  }

  // CRITICAL: Initialize Timezone Data Once on App/Widget Start
  void _initializeTimezone() {
    try {
      tzdata.initializeTimeZones();
      // Optional: Set the local location to Manila if all dates should default there
      // tz.setLocalLocation(tz.getLocation('Asia/Manila'));
      setState(() {
        _isTimezoneInitialized = true;
      });
    } catch (e) {
      // Handle error if initialization fails (e.g., package not installed)
      debugPrint("Timezone initialization failed: $e");
      setState(() {
        _isTimezoneInitialized = true; // Still allow app to run with basic Dart time
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTimezoneInitialized) {
      // Show a loading screen until initialization is complete
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Wrap the entire structure in a DefaultTabController
    return DefaultTabController(
      length: 3, // MODIFIED: Changed from 2 to 3 tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Return Process'), // General title for the section
          backgroundColor: const Color(0xFF5C7C9A),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color.fromARGB(150, 255, 255, 255),
            tabs: [
              // Tab 1: Your original page
              Tab(text: 'Return Medicines', icon: Icon(Icons.medication_liquid)),
              // Tab 2: The verification page
              Tab(text: 'Return Verification', icon: Icon(Icons.verified_user)),
              // NEW Tab 3: The transactions view page
              Tab(text: 'View Transactions', icon: Icon(Icons.list_alt)),
            ],
          ),
        ),
        // Use TabBarView to show the content for each tab
        body: const TabBarView(
          children: [
            ExpiredMedicineListTab(), // Tab 1 content
            ReturnVerificationPage(), // Tab 2 content
            ReturnViewTab(), // NEW Tab 3 content from return_view_tab.dart
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 2. Global PDF Function (Remains the same)
// --------------------------------------------------------------------------
Future<void> generateAndSavePdf(BuildContext context, List<Map<String, dynamic>> medicines) async {
  if (medicines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No items to include in the report.')),
    );
    return;
  }

  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'RETURN EXPIRED MEDICINES',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('BlueWhite Generic Pharmacy', style: pw.TextStyle(fontSize: 12)),
                pw.Text('DATE: $now',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(width: 1),
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              columnWidths: const {
                0: pw.FixedColumnWidth(0.5),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.5),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(1.0),
                5: pw.FlexColumnWidth(1.5),
              },
              headers: [
                'No.',
                'Medicine',
                'Batch No.',
                'Expiration Date',
                'Expired Quantity',
                'Supplier',
              ],
              data: List<List<String>>.generate(
                medicines.length,
                (index) => [
                  '${index + 1}',
                  medicines[index]['medicine_name'] ?? 'N/A',
                  medicines[index]['batch_num'] ?? 'N/A',
                  medicines[index]['exp_date'] ?? 'N/A',
                  medicines[index]['quantity'].toString(),
                  medicines[index]['supplier_name'] ?? 'N/A',
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  try {
    // PDF date generation does not need timezone conversion since it's just the current time
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'returned_medicines_report_$formattedDate.pdf';

    await PdfService.savePdfToDownloadsAndAppStorage(pdf, fileName);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Failed to save PDF: $e')),
    );
  }
}

// --------------------------------------------------------------------------
// 3. Expired Medicine List Tab (Return Functionality Only) - Remains the same
// --------------------------------------------------------------------------
class ExpiredMedicineListTab extends StatefulWidget {
  const ExpiredMedicineListTab({super.key});

  @override
  State<ExpiredMedicineListTab> createState() => _ExpiredMedicineListTabState();
}

class _ExpiredMedicineListTabState extends State<ExpiredMedicineListTab> {
  List<dynamic> expiredMedicines = [];
  bool _isLoading = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    fetchExpiredMedicines();
  }

  void fetchExpiredMedicines() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/medicines/expired/'));
      if (response.statusCode == 200) {
        setState(() {
          expiredMedicines = jsonDecode(response.body);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to load expired medicines: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error connecting to the server.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(int inventoryId) {
    setState(() {
      if (_selectedIds.contains(inventoryId)) {
        _selectedIds.remove(inventoryId);
      } else {
        _selectedIds.add(inventoryId);
      }
    });
  }

  // MODIFIED FUNCTION: Capture transaction_id and switch tabs
  Future<void> markSelectedAsReturned() async {
    final List<int> inventoryIds = _selectedIds.toList();

    if (inventoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please long-press to select medicines to return.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Return Selected'),
        content: Text('Mark the ${inventoryIds.length} selected items as returned? The next step is verification.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: const Text('Yes, Return Selected'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getInt('staff_id');

      if (staffId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff ID not found. Please log in again.')),
        );
        return;
      }

      int? newTransactionId; // Variable to capture the transaction ID

      if (inventoryIds.length == 1) {
        // --- Single Delete Logic ---
        final singleId = inventoryIds.first;
        final String singleDeleteUrl =
            '$_baseUrl/medicines/delete/$singleId/?staff_id=$staffId';

        final response = await http.delete(Uri.parse(singleDeleteUrl));

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          newTransactionId = responseData['transaction_id'] as int?;

        } else if (response.statusCode != 204) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          throw Exception(responseData['error'] ?? 'Server error during single return.');
        }

      } else {
        // --- Batch Delete Logic ---
        const String batchDeleteUrl =
            '$_baseUrl/medicines/batch_delete/';

        final response = await http.delete(
          Uri.parse('$batchDeleteUrl?staff_id=$staffId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'inventory_ids': inventoryIds}),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          newTransactionId = responseData['transaction_id'] as int?;

        } else if (response.statusCode != 204) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          throw Exception(responseData['error'] ?? 'Server error during batch return.');
        }
      }

      // -------------------------------------------------------------------
      // CRITICAL: Post-Success Handling (Remove items and switch tab)
      // -------------------------------------------------------------------
      if (newTransactionId != null) {
        // 1. Update UI (remove items, clear selection)
        setState(() {
          expiredMedicines.removeWhere((item) => inventoryIds.contains(item['id']));
          _selectedIds.clear();
        });

        // 2. Show Success Message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Return successful! Transaction ID: $newTransactionId. Please proceed to verification.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // 3. Switch to the Verification Tab (Index 1)
        final tabController = DefaultTabController.of(context);
        if (tabController != null) {
          tabController.animateTo(1);
        }

      } else {
          throw Exception('Return successful, but transaction ID was not received from the server.');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Return Failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = _selectedIds.isNotEmpty;
    int selectedCount = _selectedIds.length;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: isSelectionMode ? const Size.fromHeight(kToolbarHeight) : Size.zero,
        child: isSelectionMode
            ? AppBar(
                automaticallyImplyLeading: false,
                title: Text('$selectedCount Selected'),
                backgroundColor: const Color(0xFF8B0000), // Dark Red when selecting
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    onPressed: _isLoading ? null : markSelectedAsReturned,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_sweep_rounded),
                    tooltip: 'Return Selected Items',
                  ),
                ],
              )
            : AppBar(
                toolbarHeight: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
      ),
      body: _isLoading && expiredMedicines.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : expiredMedicines.isEmpty
              ? const Center(child: Text('No expired medicines to return.'))
              : RefreshIndicator(
                  onRefresh: () async {
                    fetchExpiredMedicines();
                  },
                  child: ListView.builder(
                    itemCount: expiredMedicines.length,
                    itemBuilder: (context, index) {
                      final medicine = expiredMedicines[index];
                      final inventoryId = medicine['id'] as int;
                      final isSelected = _selectedIds.contains(inventoryId);

                      return GestureDetector(
                        onLongPress: () => _toggleSelection(inventoryId),
                        onTap: isSelectionMode ? () => _toggleSelection(inventoryId) : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color.fromARGB(255, 255, 175, 175)
                                : const Color.fromARGB(255, 255, 219, 219),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color.fromARGB(255, 139, 0, 0)
                                  : const Color.fromARGB(255, 236, 155, 155)
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? Colors.red.shade900 : Colors.grey,
                                  ),
                                ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      medicine['medicine_name'] ?? 'No Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected ? Colors.red.shade900 : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Generic: ${medicine['generic_name'] ?? 'N/A'}'),
                                    Text('Batch No: ${medicine['batch_num'] ?? 'N/A'}'),
                                    Text('Supplier: ${medicine['supplier_name'] ?? 'N/A'}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    medicine['quantity']?.toString() ?? '0',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const Text('Qty', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    medicine['exp_date'] ?? 'N/A',
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const Text('Expired Date', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}