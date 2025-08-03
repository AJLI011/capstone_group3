import 'package:flutter/material.dart';

class PromoView extends StatelessWidget {
  const PromoView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Promos"),
        backgroundColor: const Color(0xFF003B8D),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search Bar with filter icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search),
                  hintText: 'Search',
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.tune),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Promo cards grid (currently empty)
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemCount: 0, // 🔁 replace with actual count when data is available
                itemBuilder: (context, index) {
                  return const Placeholder(); // Replace with promo card widget
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
