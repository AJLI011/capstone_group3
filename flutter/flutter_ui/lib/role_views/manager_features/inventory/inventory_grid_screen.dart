// Location: flutter\flutter_ui\lib\role_views\manager_features\inventory\inventory_grid_screen.dart

import 'package:flutter/material.dart';
import 'inventory_detail_screen.dart';
import 'total_quantity.dart'; // Assuming this defines the TotalQuantity class
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🎯 YOUR SPECIFIC IMPORT PATH MUST MATCH THE FILE LOCATION
import 'package:flutter_ui/services/responsive_scale2.dart'; 

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://bluewhiteph.pythonanywhere.com/',
);

// InventoryResponse and InventoryApiService definitions
class InventoryResponse {
  final List<TotalQuantity> items;
  final int totalCount;
  final bool hasMore;

  InventoryResponse({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });
}

class InventoryApiService {
  static const String inventoryPath = 'api/inventory/';
  static const String totalQuantitiesPath = 'api/inventory/total-quantities/';
  
  // 🚀 NEW PATH FOR DEDUCTION
  static const String deductBatchStockPath = 'api/inventory/deduct-batch-stock/';

  static Future<InventoryResponse> fetchInventoryItems({
    int limit = 10,
    int offset = 0,
    String? searchQuery, 
    String? category, 
  }) async {
    try {
      String url = '$API_BASE$inventoryPath?limit=$limit&offset=$offset';

      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&q=${Uri.encodeQueryComponent(searchQuery)}';
      }

      if (category != null && category.isNotEmpty) {
        url += '&category=$category';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        final List<dynamic> data = responseData['items'] ?? [];
        final List<TotalQuantity> items = data.map((json) => TotalQuantity.fromJson(json)).toList();

        return InventoryResponse(
          items: items,
          totalCount: responseData['total_count'] ?? 0,
          hasMore: responseData['has_more'] ?? false,
        );
      } else {
        throw Exception('Failed to load inventory data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching inventory: $e');
    }
  }

  static Future<void> syncTotalQuantities() async {
    try {
      final url = '$API_BASE$totalQuantitiesPath';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        print('✅ Total quantity synced');
      } else {
        print('❌ Failed to sync: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error syncing total quantity: $e');
    }
  }
  
  // 🚀 NEW METHOD: Deduction API Call
  static Future<void> deductBatchStock({
    required String batchNumber, 
    required int quantity, 
    required String reason, 
  }) async {
    if (quantity <= 0) {
      throw Exception('Deduction quantity must be greater than zero.'); 
    }
    
    try {
      final url = 'http://$API_BASE$deductBatchStockPath'; // Use http:// if API_BASE includes port
      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          // Ensure any necessary authorization headers are added here
        },
        body: jsonEncode(<String, dynamic>{
          'batch_number': batchNumber, 
          'quantity': quantity,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Batch stock deduction successful for Batch $batchNumber');
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['detail'] ?? 'Unknown deduction error.';
        throw Exception('Failed to deduct batch stock: ${response.statusCode}. Detail: $errorMessage');
      }
    } catch (e) {
      throw Exception('Network or processing error during batch stock deduction: $e');
    }
  }
}

class InventoryGridScreen extends StatefulWidget {
  const InventoryGridScreen({super.key});

  @override
  State<InventoryGridScreen> createState() => _InventoryGridScreenState();
}

// 🎯 CRITICAL: This line connects the mixin to the State class.
class _InventoryGridScreenState extends State<InventoryGridScreen> with ResponsiveScale {
  final ScrollController _scrollController = ScrollController();
  List<TotalQuantity> _items = [];
  String _selectedCategory = '';
  bool _sortAZ = true;
  bool _showSearch = false;
  String _searchQuery = '';

  int _offset = 0;
  final int _limit = 10;
  bool _isLoading = false;
  bool _hasMoreItems = true;
  int _totalCount = 0;

  final List<Map<String, String>> _categoryChoices = [
    {'value': '', 'label': 'Categories'},
    {'value': 'analgesics', 'label': 'Analgesics'},
    {'value': 'antibiotics', 'label': 'Antibiotics'},
    {'value': 'antivirals', 'label': 'Antivirals'},
    {'value': 'antihypertensives', 'label': 'Antihypertensives'},
    {'value': 'antidiabetics', 'label': 'Antidiabetics'},
    {'value': 'gastrointestinal_medicines', 'label': 'Gastrointestinal Medicines'},
    {'value': 'antihistamines', 'label': 'Antihistamines'},
    {'value': 'cough_and_cold_medicines', 'label': 'Cough and Cold Medicines'},
    {'value': 'vitamins_and_supplements', 'label': 'Vitamins and Supplements'},
    {'value': 'cardiovascular_medicines', 'label': 'Cardiovascular Medicines'},
    {'value': 'anti_asthma_and_respiratory_medicines', 'label': 'Anti-asthma and Respiratory Medicines'},
    {'value': 'antimalarials', 'label': 'Antimalarials'},
    {'value': 'antiparasitics', 'label': 'Antiparasitics'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    syncAndLoadInventory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreItems) {
      loadMoreItems();
    }
  }
  
  void _onSearchChanged(String value) {
      setState(() => _searchQuery = value);
      syncAndLoadInventory(); 
  }
  
  void _onCategoryChanged(String value) {
      setState(() => _selectedCategory = value);
      syncAndLoadInventory(); 
  }

  Future<void> syncAndLoadInventory() async {
    setState(() {
      _items = [];
      _offset = 0;
      _totalCount = 0; 
      _hasMoreItems = true;
    });
    // This sync is generally unnecessary if the totals are fetched via the inventory endpoint, 
    // but we'll keep it as you had it.
    await InventoryApiService.syncTotalQuantities(); 
    await loadInventory();
  }

  Future<void> loadInventory() async {
    if (_isLoading || !_hasMoreItems) return;
    setState(() => _isLoading = true);
    try {
      final response = await InventoryApiService.fetchInventoryItems(
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery,
        category: _selectedCategory,
      );

      setState(() {
        _items.addAll(response.items);
        _offset += _limit;
        _totalCount = response.totalCount;
        _hasMoreItems = response.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading inventory: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> loadMoreItems() async {
    if (_isLoading || !_hasMoreItems) return;
    await loadInventory();
  }

List<TotalQuantity> get _sortedItems {
    final List<TotalQuantity> items = List.from(_items); 

    int compareName(TotalQuantity a, TotalQuantity b) {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }

    if (_sortAZ) {
      items.sort(compareName);
    } else {
      items.sort((a, b) => compareName(b, a)); 
    }
    
    return items;
}

  @override
  Widget build(BuildContext context) {
    final displayItems = _sortedItems;
    
    // 💡 SCALING APPLIED: All these methods should now be available:
    final double scaledSpacing = scaleValue(context, 12);
    final double scaledPaddingH = scaleValue(context, 12);
    final double scaledPaddingV = scaleValue(context, 6);
    final double scaledSmallSizedBox = scaleValue(context, 8);
    final double scaledCardPadding = scaleValue(context, 8);
    final double scaledIconSize = scaleValue(context, 24);
    final double scaledImageAreaHeight = scaleValue(context, 120);
    final double scaledIconLarge = scaleValue(context, 80);

    return Scaffold(
      appBar: AppBar(
        title: Text('Inventory', style: TextStyle(fontSize: scaleFontSize(context, 20))),
        backgroundColor: const Color(0xFF5C7C9A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
                _sortAZ ? Icons.sort_by_alpha : Icons.sort,
                size: scaledIconSize,
            ),
            onPressed: () {
              setState(() => _sortAZ = !_sortAZ);
            },
          ),
          IconButton(
            icon: Icon(
                Icons.search,
                size: scaledIconSize,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                   _onSearchChanged(''); 
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Container(
              padding: EdgeInsets.symmetric(horizontal: scaledPaddingH, vertical: scaledPaddingV),
              color: Colors.white,
              child: TextField(
                onChanged: _onSearchChanged, 
                decoration: InputDecoration(
                  hintText: 'Search...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: scaledPaddingH, vertical: scaleValue(context, 10)),
                  border: const OutlineInputBorder(),
                ),
                style: TextStyle(fontSize: scaleFontSize(context, 16)),
              ),
            ),
          Container(
            padding: EdgeInsets.all(scaledPaddingH),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _categoryChoices.map((choice) {
                      return DropdownMenuItem<String>(
                        value: choice['value'],
                        child: Text(
                          choice['label']!,
                          style: TextStyle(fontSize: scaleFontSize(context, 14)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      _onCategoryChanged(value ?? '');
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: scaledSmallSizedBox),
          Expanded(
            child: displayItems.isEmpty && !_isLoading 
                ? Center(
                    child: Text(
                      _totalCount == 0 ? 'No medicines available.' : 'Loading...',
                      style: TextStyle(fontSize: scaleFontSize(context, 16)),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(scaledSpacing),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: scaledSpacing,
                      mainAxisSpacing: scaledSpacing,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: displayItems.length + (_isLoading && _hasMoreItems ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == displayItems.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final item = displayItems[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(
                            color: const Color(0xFF396AAB),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(scaleValue(context, 12)),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(scaleValue(context, 12)),
                          // 👇 MODIFIED: Await navigation and refresh the grid on return
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InventoryDetailScreen(item: item),
                              ),
                            );
                            // Once back, force a reload of the inventory totals to reflect any deductions
                            syncAndLoadInventory(); 
                          },
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: scaledCardPadding,
                                  vertical: scaleValue(context, 16.0),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (item.image.isNotEmpty)
                                      SizedBox(
                                        height: scaledImageAreaHeight,
                                        child: Center(
                                          child: Image.network(
                                            item.image,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) =>
                                                Icon(
                                                    Icons.image_not_supported, 
                                                    size: scaledIconLarge,
                                                    color: Colors.grey
                                                ),
                                          ),
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        height: scaledImageAreaHeight,
                                        child: Center(
                                          child: Icon(
                                              Icons.medication, 
                                              size: scaledIconLarge,
                                              color: Colors.grey
                                          ),
                                        ),
                                      ),
                                    SizedBox(height: scaleValue(context, 10)),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.name,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: scaleFontSize(context, 18),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            item.genericName,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: scaleFontSize(context, 14),
                                              color: Colors.grey,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: scaledCardPadding,
                                right: scaledCardPadding,
                                child: Container(
                                  padding: EdgeInsets.all(scaleValue(context, 4)),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF396AAB),
                                    borderRadius: BorderRadius.circular(scaleValue(context, 8)),
                                  ),
                                  child: Text(
                                    "Qty: ${item.totalQuantity}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: scaleFontSize(context, 17),
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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