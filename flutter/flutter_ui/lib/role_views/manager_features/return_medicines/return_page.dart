import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ui/services/pdf_service.dart'; // Import your existing PdfService
// 🎯 IMPORT THE NEW PAGE
import 'return_verify.dart'; 

// --------------------------------------------------------------------------
// 1. New Parent Widget to Handle Tabs (This is the page the user will navigate to)
// --------------------------------------------------------------------------
class ReturnMedicinePage extends StatelessWidget {
  const ReturnMedicinePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap the entire structure in a DefaultTabController
    return DefaultTabController(
      length: 2, // We have two tabs now
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
              // Tab 1: Your original page, renamed for clarity
              Tab(text: 'Return Medicines', icon: Icon(Icons.medication_liquid)), 
              // Tab 2: The new verification page
              Tab(text: 'Return Verification', icon: Icon(Icons.verified_user)),
            ],
          ),
        ),
        // Use TabBarView to show the content for each tab
        body: const TabBarView(
          children: [
            ExpiredMedicineListTab(), // Your original content
            ReturnVerificationPage(), // The new verification content
          ],
        ),
        // Move the FAB logic to the list tab or remove it if not needed for the verification tab
      ),
    );
  }
}


// --------------------------------------------------------------------------
// 2. Refactored Widget (Your old ReturnMedicinePage, now renamed)
// --------------------------------------------------------------------------
class ExpiredMedicineListTab extends StatefulWidget {
  const ExpiredMedicineListTab({super.key});

  @override
  State<ExpiredMedicineListTab> createState() => _ExpiredMedicineListTabState();
}

// Renamed the State class to match the new Widget name
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
          await http.get(Uri.parse('http://192.168.0.104:8000/api/medicines/expired/'));
      if (response.statusCode == 200) {
        setState(() {
          expiredMedicines = jsonDecode(response.body);
        });
        print(jsonEncode(expiredMedicines));
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
        content: Text('Mark the ${inventoryIds.length} selected items as returned?'),
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

      if (inventoryIds.length == 1) {
        final singleId = inventoryIds.first;
        final String singleDeleteUrl =
          'http://192.168.0.104:8000/api/medicines/delete/$singleId/?staff_id=$staffId';
          
        final response = await http.delete(Uri.parse(singleDeleteUrl));

        if (response.statusCode == 200 || response.statusCode == 204) {
          setState(() {
            expiredMedicines.removeWhere((item) => item['id'] == singleId);
            _selectedIds.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Successfully returned 1 medicine.')),
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '❌ Failed to return medicine. Server responded with ${response.statusCode}')),
          );
        }

      } else {
        const String batchDeleteUrl =
            'http://192.168.0.104:8000/api/medicines/batch_delete/';

        final response = await http.delete(
          Uri.parse('$batchDeleteUrl?staff_id=$staffId'), 
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'inventory_ids': inventoryIds}), 
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final int count = responseData['successful_count'] ?? inventoryIds.length;

          setState(() {
            expiredMedicines.removeWhere((item) => _selectedIds.contains(item['id']));
            _selectedIds.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Successfully returned $count expired medicines.')),
          );
        } else {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '❌ Batch Return Failed: ${responseData['error'] ?? 'Unknown error'}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ An error occurred during return: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // PDF function remains unchanged
  Future<void> generateAndSavePdf(List<Map<String, dynamic>> medicines) async {
    // NOTE: If you move the FloatingActionButton, this logic should remain in the widget
    // where the FAB resides, or be passed down as a callback.
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
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
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'returned_medicines_report_$formattedDate.pdf';

      await PdfService.savePdfToDownloadsAndAppStorage(pdf, fileName);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to save PDF: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = _selectedIds.isNotEmpty;
    int selectedCount = _selectedIds.length;
    
    // The AppBar contents are moved to the main page's AppBar. 
    // This widget now only contains the content for its tab.
    return Scaffold(
      // The AppBar is NOT included here as it's in the parent widget (ReturnMedicineMainPage)
      appBar: PreferredSize(
        preferredSize: isSelectionMode ? const Size.fromHeight(kToolbarHeight) : Size.zero,
        child: isSelectionMode
            ? AppBar(
                automaticallyImplyLeading: false, // Don't show the back button on the inner AppBar
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
                // Use a standard AppBar height, but keep it invisible/empty when not in selection mode
                toolbarHeight: 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
      ),
      body: _isLoading && expiredMedicines.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : expiredMedicines.isEmpty
              ? const Center(child: Text('No expired medicines to return.'))
              : ListView.builder(
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
      // FAB is kept here since it only relates to the expired list data
      floatingActionButton: FloatingActionButton(
        onPressed: expiredMedicines.isEmpty || isSelectionMode ? null : () =>
            generateAndSavePdf(expiredMedicines.cast<Map<String, dynamic>>()),
        backgroundColor: const Color.fromARGB(255, 212, 86, 86),
        foregroundColor: Colors.black,
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}