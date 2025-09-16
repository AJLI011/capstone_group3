import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PromoMedicinePage extends StatefulWidget {
  const PromoMedicinePage({Key? key}) : super(key: key);

  @override
  State<PromoMedicinePage> createState() => _PromoMedicinePageState();
}

class _PromoMedicinePageState extends State<PromoMedicinePage> {
  // Master list of all promo-eligible medicines
  List<dynamic> _fullPromoMedicines = [];
  // The list displayed to the user, either paginated or filtered
  List<dynamic> _filteredPromoMedicines = [];
  // Controller for the search bar
  final TextEditingController _searchController = TextEditingController();

  // Pagination & Lazy Loading State
  bool _isLoading = false;
  bool _hasMore = true;
  int _nextIndex = 0;
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _fetchAllPromoMedicines();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterMedicines);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Method to handle scroll events for lazy loading
  void _onScroll() {
    if (!_isLoading && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.95) {
      if (_hasMore && _searchController.text.isEmpty) {
        _loadMoreMedicines();
      }
    }
  }

  // Client-side filtering method
  void _filterMedicines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // If the search query is empty, revert to the lazy-loaded list
        _filteredPromoMedicines = _fullPromoMedicines.sublist(0, _nextIndex);
      } else {
        // Otherwise, filter the entire fetched data
        _filteredPromoMedicines = _fullPromoMedicines.where((item) {
          final name = item['medicine_name']?.toLowerCase() ?? '';
          final generic = item['generic_name']?.toLowerCase() ?? '';
          return name.contains(query) || generic.contains(query);
        }).toList();
      }
    });
  }
  
  // Client-side pagination method
  void _loadMoreMedicines() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay for a better user experience
    Future.delayed(const Duration(milliseconds: 500), () {
      final int newLength = _nextIndex + _pageSize;
      final int end = newLength > _fullPromoMedicines.length ? _fullPromoMedicines.length : newLength;

      setState(() {
        _filteredPromoMedicines.addAll(_fullPromoMedicines.sublist(_nextIndex, end));
        _nextIndex = end;
        _isLoading = false;
        if (_nextIndex >= _fullPromoMedicines.length) {
          _hasMore = false;
        }
      });
    });
  }

  // Fetch all promo-eligible medicines
  Future<void> _fetchAllPromoMedicines() async {
    setState(() {
      _isLoading = true;
    });
    const String url = 'http://10.0.2.2:8000/api/medicines/expiring-soon/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> fetchedData = json.decode(response.body);

        // FEFO sorting by expiration date
        fetchedData.sort((a, b) => DateTime.parse(a['exp_date']).compareTo(DateTime.parse(b['exp_date'])));

        setState(() {
          _fullPromoMedicines = fetchedData;
          _isLoading = false;
          _hasMore = fetchedData.length > _pageSize;
        });
        
        // Immediately load the first page of data
        _loadMoreMedicines();
      } else {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        print('Failed to load promo medicines. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      print('Error fetching promo medicines: $e');
    }
  }

  Future<void> setPromo(int inventoryId, String startDate, String endDate) async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff ID not found. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8000/api/inventory/$inventoryId/set-promo/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'start_date': startDate,
        'end_date': endDate,
        'staff_id': staffId,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promo set!')),
      );
      _fetchAllPromoMedicines(); // Refresh list
    } else {
      print('Failed to set promo: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error setting promo')),
      );
    }
  }

  Future<void> removePromo(int inventoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getInt('staff_id');

    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff ID not found. Please log in again.')),
      );
      return;
    }

    final url = Uri.parse('http://10.0.2.2:8000/api/inventory/remove-promo/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'inventory_id': inventoryId,
          'staff_id': staffId,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promo removed successfully')),
        );
        _fetchAllPromoMedicines(); // Refresh list
      } else {
        throw Exception('Failed to remove promo: ${response.body}');
      }
    } catch (e) {
      print('Error removing promo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove promo')),
      );
    }
  }

  void showPromoDialog(int inventoryId, bool isPromoAlready) {
    if (isPromoAlready) return;

    // Define the target time zone
    final location = tz.getLocation('Asia/Manila');
    // Get the current date and time in the Manila time zone
    final nowInManila = tz.TZDateTime.now(location);
    // Create a date-only DateTime object for today, at the start of the day
    final todayInManila = tz.TZDateTime(location, nowInManila.year, nowInManila.month, nowInManila.day);

    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Set Promo Dates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  selectedStartDate != null
                      ? 'Start: ${selectedStartDate!.toIso8601String().split('T').first}'
                      : 'Choose Start Date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? todayInManila,
                    firstDate: todayInManila,
                    lastDate: DateTime(2100), 
                  );
                  if (picked != null) {
                    setState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
              ),
              ListTile(
                title: Text(
                  selectedEndDate != null
                      ? 'End: ${selectedEndDate!.toIso8601String().split('T').first}'
                      : 'Choose End Date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDate ?? selectedStartDate ?? todayInManila,
                    firstDate: selectedStartDate ?? todayInManila,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedEndDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStartDate != null && selectedEndDate != null) {
                  Navigator.pop(context);
                  setPromo(
                    inventoryId,
                    DateFormat('yyyy-MM-dd').format(selectedStartDate!),
                    DateFormat('yyyy-MM-dd').format(selectedEndDate!),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please choose both dates')),
                  );
                }
              },
              child: const Text('Set Promo'),
            ),
          ],
        ),
      ),
    );
  }

  void showRemovePromoConfirmationDialog(int inventoryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Removal'),
        content: const Text('Are you sure you want to remove the promo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              removePromo(inventoryId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo Medicines'),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search medicine...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: _fullPromoMedicines.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPromoMedicines.isEmpty && _searchController.text.isNotEmpty
                ? const Center(child: Text('No matching medicines found.'))
                : _filteredPromoMedicines.isEmpty
                  ? const Center(child: Text('No medicines eligible for promo.'))
                  : ListView.builder(
                      controller: _scrollController,
                      // Only show loading indicator if not searching and there's more to load
                      itemCount: _filteredPromoMedicines.length + (_hasMore && _searchController.text.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredPromoMedicines.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        final item = _filteredPromoMedicines[index];
                        final isPromo = item['is_promo'] == true || item['is_promo'] == 1;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9C4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFEE58)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left side
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['medicine_name'] ?? 'No Name',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${item['generic_name'] ?? 'N/A'}'),
                                    Text('${item['batch_num'] ?? 'N/A'}'),
                                    Text('${item['supplier_name'] ?? 'N/A'}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Right side
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    item['quantity']?.toString() ?? '0',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['exp_date'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                  const SizedBox(height: 8),
                                  if (!isPromo)
                                    ElevatedButton(
                                      onPressed: () => showPromoDialog(item['id'], isPromo),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.yellow[700],
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Promo'),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => showRemovePromoConfirmationDialog(item['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Remove Promo'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}