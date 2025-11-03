import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GoodStockStaffPage extends StatefulWidget {
  const GoodStockStaffPage({super.key});

  @override
  State<GoodStockStaffPage> createState() => _GoodStockStaffPageState();
}

class _GoodStockStaffPageState extends State<GoodStockStaffPage> {
  // This will hold the entire list of data fetched from the API
  List<dynamic> _fullGoodStocks = [];
  // This is the list that will be displayed in chunks and filtered by search
  List<dynamic> _filteredGoodStocks = [];
  // Controller for the search bar
  final TextEditingController _searchController = TextEditingController();

  // Pagination & Lazy Loading State
  bool _isLoading = false;
  bool _hasMore = true;
  int _nextIndex = 0; // The index to start loading from in _fullGoodStocks
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initial fetch of ALL data from the API
    _fetchAllGoodStocks();
    // Add a listener to the scroll controller to trigger client-side lazy loading
    _scrollController.addListener(_onScroll);
    // Add a listener to the search controller to filter the list as the user types
    _searchController.addListener(_filterGoodStocks);
  }

  @override
  void dispose() {
    // Clean up controllers and listeners when the widget is disposed
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Method to handle scroll events for lazy loading
  void _onScroll() {
    // Check if the user is at the end, we're not loading, and have more data to show.
    // Also, lazy loading is only active when the search bar is empty.
    if (!_isLoading && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.95) {
      if (_hasMore && _searchController.text.isEmpty) {
        _loadMoreStocks();
      }
    }
  }

  // Method to filter the list based on the search query
  void _filterGoodStocks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // If the search query is empty, reset the displayed list to the loaded chunks
        _filteredGoodStocks = _fullGoodStocks.sublist(0, _nextIndex);
      } else {
        // Otherwise, filter the entire fetched data based on the query
        _filteredGoodStocks = _fullGoodStocks.where((stock) {
          final medicineName = stock['medicine_name']?.toLowerCase() ?? '';
          final genericName = stock['generic_name']?.toLowerCase() ?? '';
          return medicineName.contains(query) || genericName.contains(query);
        }).toList();
      }
    });
  }

  // New method for client-side pagination
  void _loadMoreStocks() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Simulate network delay for a better user experience
    Future.delayed(const Duration(milliseconds: 500), () {
      final int newLength = _nextIndex + _pageSize;
      final int end = newLength > _fullGoodStocks.length ? _fullGoodStocks.length : newLength;

      setState(() {
        _filteredGoodStocks.addAll(_fullGoodStocks.sublist(_nextIndex, end));
        _nextIndex = end;
        _isLoading = false;
        if (_nextIndex >= _fullGoodStocks.length) {
          _hasMore = false;
        }
      });
    });
  }

  // Modified fetch method to get all data at once
  Future<void> _fetchAllGoodStocks() async {
    setState(() {
      _isLoading = true;
    });

    final String url = 'http://192.168.1.21:8000/api/medicines/good-stock/';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedData = json.decode(response.body);

        // Sort the fetched data once
        fetchedData.sort((a, b) {
          final dateA = a['exp_date'] != null ? DateTime.tryParse(a['exp_date']) : null;
          final dateB = b['exp_date'] != null ? DateTime.tryParse(b['exp_date']) : null;
          if (dateA != null && dateB != null) {
            return dateA.compareTo(dateB);
          }
          return 0;
        });

        setState(() {
          _fullGoodStocks = fetchedData;
          _isLoading = false;
          _hasMore = fetchedData.length > _pageSize;
        });
        
        // Immediately load the first page of data
        _loadMoreStocks();

      } else {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        print('Failed to load good stocks. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      print('Error fetching good stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Good Stocks'),
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
            child: _fullGoodStocks.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredGoodStocks.isEmpty && _searchController.text.isNotEmpty
                ? const Center(child: Text('No matching medicines found.'))
                : _filteredGoodStocks.isEmpty
                  ? const Center(child: Text('No good stock medicines'))
                  : ListView.builder(
                      controller: _scrollController,
                      // Only show loading indicator if not searching and there's more to load
                      itemCount: _filteredGoodStocks.length + (_hasMore && _searchController.text.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _filteredGoodStocks.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        
                        final stock = _filteredGoodStocks[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stock['medicine_name'] ?? 'No Name',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('Generic: ${stock['generic_name'] ?? 'N/A'}'),
                                    Text('Batch: ${stock['batch_num'] ?? 'N/A'}'),
                                    Text('Quantity: ${stock['quantity'] ?? '0'}'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Expires: ${stock['exp_date'] ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                  Text('Supplier: ${stock['supplier_name'] ?? 'N/A'}'),
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