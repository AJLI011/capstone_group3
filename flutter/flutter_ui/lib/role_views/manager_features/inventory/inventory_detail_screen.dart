import 'package:flutter/material.dart';
import 'dart:convert';
import 'total_quantity.dart';
import 'package:http/http.dart' as http;

// NEW: API base URL is now a constant defined using --dart-define.
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://192.168.1.6:8000/',
);

// ===================== MODEL: BatchDetail =====================
class BatchDetail {
  final String batchNumber;
  final String expirationDate;
  final int quantity;
  final double price;
  final String name;
  final String genericName;
  final bool isPromo;
  final String? promoStartDate;
  final String? promoEndDate;

  BatchDetail({
    required this.batchNumber,
    required this.expirationDate,
    required this.quantity,
    required this.price,
    required this.name,
    required this.genericName,
    required this.isPromo,
    required this.promoStartDate,
    required this.promoEndDate,
  });

  factory BatchDetail.fromJson(Map<String, dynamic> json) {
    return BatchDetail(
      batchNumber: json['batch_num'] ?? '',
      expirationDate: json['exp_date'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      name: json['name'] ?? '',
      genericName: json['generic_name'] ?? '',
      isPromo: json['is_promo'] ?? false,
      promoStartDate: json['promo_start_date'],
      promoEndDate: json['promo_end_date'],
    );
  }
}

// ===================== SERVICE: Fetch Batch Details =====================
class InventoryApiService {
  // MODIFIED: Replaced the hardcoded URL with a constant that uses the API_BASE.
  static const String totalQuantitiesPath = 'api/inventory/total-quantities/';

  // MODIFIED: Added limit and offset parameters to support lazy loading for batch details.
  static Future<List<BatchDetail>> fetchBatchDetails(
    int medicineId, {
    int limit = 10,
    int offset = 0,
  }) async {
    // MODIFIED: The URL now includes limit and offset query parameters and uses the API_BASE constant.
    final String batchDetailsUrl =
        '${API_BASE}api/inventory/batches/$medicineId/?limit=$limit&offset=$offset';

    try {
      final response = await http.get(Uri.parse(batchDetailsUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => BatchDetail.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load batch details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching batch details: $e');
    }
  }
}

// ===================== UI: Inventory Detail Screen =====================
class InventoryDetailScreen extends StatefulWidget {
  final TotalQuantity item;

  const InventoryDetailScreen({super.key, required this.item});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  // NEW: A ScrollController to listen for scroll events.
  final ScrollController _scrollController = ScrollController();
  final List<BatchDetail> _batches = [];
  // NEW: State variables for lazy loading.
  bool _isLoading = false;
  bool _hasMoreItems = true;
  int _offset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    // NEW: Add a listener to detect when the user scrolls to the end of the list.
    _scrollController.addListener(_onScroll);
    _loadBatches();
  }

  @override
  void dispose() {
    // NEW: Dispose the ScrollController to prevent memory leaks.
    _scrollController.dispose();
    super.dispose();
  }

  // NEW: Function to check if the user has reached the end of the list.
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoading &&
        _hasMoreItems) {
      _loadBatches();
    }
  }

  // MODIFIED: This function now handles paginated fetching and state management.
  Future<void> _loadBatches() async {
    if (_isLoading || !_hasMoreItems) return;
    setState(() => _isLoading = true);

    try {
      // MODIFIED: Call the API with the limit and offset.
      final fetchedBatches = await InventoryApiService.fetchBatchDetails(
        widget.item.medicineId,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _batches.addAll(fetchedBatches);
        // NEW: Update offset for the next fetch.
        _offset += _limit;
        // NEW: Determine if there are more items to load.
        _hasMoreItems = fetchedBatches.length == _limit;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading batches: $e");
      setState(() => _isLoading = false);
    }
  }

  bool shouldShowPromoStar(BatchDetail batch) {
    if (!batch.isPromo || batch.promoStartDate == null) return false;

    try {
      final startDate = DateTime.parse(batch.promoStartDate!);
      final now = DateTime.now();
      return !now.isBefore(startDate); // Show star if today >= promoStartDate
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // MODIFIED: The FutureBuilder is replaced with a direct check of the state variables.
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
      ),
      body: _batches.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty && !_hasMoreItems && !_isLoading
              ? const Center(child: Text('No batch details available.'))
              : ListView.builder(
                  // NEW: Assign the ScrollController to the ListView.
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  // MODIFIED: Add an item for the loading indicator if more data is being fetched.
                  itemCount: _batches.length + (_isLoading && _hasMoreItems ? 1 : 0),
                  itemBuilder: (context, index) {
                    // NEW: Check if the current index is for the loading indicator.
                    if (index == _batches.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final batch = _batches[index];
                    final showPromo = shouldShowPromoStar(batch);

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${widget.item.name} (${widget.item.genericName}) ${showPromo ? "⭐️" : ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Qty: ${batch.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Batch No: ${batch.batchNumber}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '₱${batch.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Expiration Date: ${batch.expirationDate}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (batch.isPromo && batch.promoStartDate != null && batch.promoEndDate != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Start: ${batch.promoStartDate}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'End: ${batch.promoEndDate}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}