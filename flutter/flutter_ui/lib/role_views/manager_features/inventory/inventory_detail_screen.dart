import 'package:flutter/material.dart';
import 'models/total_quantity.dart';
import 'models/batch_detail.dart';
import 'models/inventory_api_service.dart';

class InventoryDetailScreen extends StatefulWidget {
  final TotalQuantity item;

  const InventoryDetailScreen({super.key, required this.item});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late Future<List<BatchDetail>> _batchDetails;

  @override
  void initState() {
    super.initState();
    _batchDetails =
        InventoryApiService.fetchBatchDetails(widget.item.medicineId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name),
        backgroundColor: const Color(0xFF396AAB),
      ),
      body: FutureBuilder<List<BatchDetail>>(
        future: _batchDetails,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No batch details available.'));
          }

          final batches = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];

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
                      // Row: Generic (Brand) and Qty
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.item.genericName} (${widget.item.name})',
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

                      // Row: Batch No and Price
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

                      // Expiration Date
                      Text(
                        'Expiration Date: ${batch.expirationDate}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
