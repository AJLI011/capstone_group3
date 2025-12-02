// medicine_view.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'medicine_detail_page.dart';

// API base URL constant for consistent API calls.
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000/',
);

class Medicine {
  final int id;
  final String name;
  final String genericName;
  final String imageUrl;
  final double price;
  final String category;

  Medicine({
    required this.id,
    required this.name,
    required this.genericName,
    required this.imageUrl,
    required this.price,
    required this.category,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'],
      name: json['name'],
      genericName: json['generic_name'] ?? '',
      imageUrl: json['image'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      category: json['category'] ?? '',
    );
  }
}

class MedicineView extends StatefulWidget {
  final int customerId;
  final String selectedCategory;
  final String searchQuery;

  const MedicineView({
    super.key,
    required this.customerId,
    this.selectedCategory = 'all',
    this.searchQuery = '',
  });

  @override
  State<MedicineView> createState() => _MedicineViewState();
}

class _MedicineViewState extends State<MedicineView> {
  final ScrollController _scrollController = ScrollController();
  List<Medicine> _medicines = [];
  // State variables to manage the lazy loading process.
  bool _isLoading = false;
  bool _hasMoreItems = true;
  int _offset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    // Add a listener to the ScrollController.
    _scrollController.addListener(_onScroll);
    _resetAndFetchMedicines();
  }

  @override
  void didUpdateWidget(covariant MedicineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 🔥 CRITICAL FIX: Reset and fetch data if category or search query changes.
    if (widget.selectedCategory != oldWidget.selectedCategory ||
        widget.searchQuery != oldWidget.searchQuery) {
      
      // Synchronously clear the list and reset offset/flags
      // This ensures the view is cleared BEFORE the new API response arrives.
      setState(() {
        _medicines = []; 
        _offset = 0;
        _hasMoreItems = true;
        _isLoading = false;
      });
      // Start the fresh fetch for the new criteria
      _fetchMedicines();
    }
  }

  @override
  void dispose() {
    // Dispose the ScrollController to prevent memory leaks.
    _scrollController.dispose();
    super.dispose();
  }

  // Function to check if the user has reached the end of the list.
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMoreItems) {
      _fetchMedicines();
    }
  }

  // Used only for the initial load in initState.
  Future<void> _resetAndFetchMedicines() async {
    // Note: We don't need to clear _medicines here as it's empty in initState.
    // The main reset logic is in didUpdateWidget.
    await _fetchMedicines();
  }

  Future<void> _fetchMedicines() async {
    // Prevents starting a new request if one is already running or if no more items exist.
    if (_isLoading || !_hasMoreItems) return;

    setState(() {
      _isLoading = true;
    });

    // Construct the URL with all query parameters.
    String url = '${API_BASE}api/customer/medicines/?';
    url += 'limit=$_limit&offset=$_offset';

    if (widget.selectedCategory != 'all') {
      url += '&category=${widget.selectedCategory}';
    }
    if (widget.searchQuery.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(widget.searchQuery)}';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // Add new results to the now-cleared list
          _medicines.addAll(data.map((json) => Medicine.fromJson(json)).toList());
          _offset += _limit;
          // Check if the received items are less than the limit, indicating end of list.
          _hasMoreItems = data.length == _limit;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load medicines: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching medicines: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMedicineCard(Medicine med) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicineDetailPage(
              medicineId: med.id,
              customerId: widget.customerId,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: med.imageUrl.isNotEmpty
                    ? Image.network(
                        med.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                                child: Icon(Icons.medication, size: 48, color: Colors.grey)),
                      )
                    : const Center(
                        child: Icon(Icons.medication, size: 48, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              med.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              med.genericName,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '₱${med.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.end,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _medicines.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty && !_hasMoreItems
              ? Center(
                  child: Text(
                    (widget.searchQuery.isNotEmpty)
                        ? "No medicines found for '${widget.searchQuery}'"
                        : "No medicines available for the category: ${widget.selectedCategory}",
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    // Assign the ScrollController to the GridView.
                    controller: _scrollController,
                    // Add an item for the loading indicator.
                    itemCount: _medicines.length + (_isLoading && _hasMoreItems ? 1 : 0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemBuilder: (context, index) {
                      // Check if the current index is the last item for the loading indicator.
                      if (index == _medicines.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildMedicineCard(_medicines[index]);
                    },
                  ),
                ),
    );
  }
}