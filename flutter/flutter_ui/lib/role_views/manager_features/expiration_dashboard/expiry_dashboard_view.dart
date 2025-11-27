import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'good_stock_page.dart';
import 'expiring_soon_page.dart';
import 'expired_stock_page.dart';

class ExpiryDashboardView extends StatefulWidget {
  const ExpiryDashboardView({super.key});

  @override
  State<ExpiryDashboardView> createState() => _ExpiryDashboardViewState();
}

class _ExpiryDashboardViewState extends State<ExpiryDashboardView> {
  int goodStockCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;

  final String baseUrl = 'http://10.0.2.2:8000/api/medicines';

  @override
  void initState() {
    super.initState();
    fetchAllCounts();
  }

  Future<void> fetchAllCounts() async {
    await Future.wait([
      fetchCount('$baseUrl/good-stock/', (count) => goodStockCount = count),
      fetchCount('$baseUrl/expiring-soon/', (count) => expiringSoonCount = count),
      fetchCount('$baseUrl/expired/', (count) => expiredCount = count),
    ]);
    setState(() {}); // Refresh UI after all fetches complete
  }

  Future<void> fetchCount(String url, Function(int) setCount) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          setCount(data.length);
        });
      } else {
        setState(() {
          setCount(0);
        });
      }
    } catch (e) {
      print("Error fetching from $url: $e");
      setState(() {
        setCount(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiration Dashboard'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded( // <--- Wrap each status button with Expanded
              child: _buildStatusButton(
                context,
                label: 'GOOD STOCKS',
                count: goodStockCount,
                color: Colors.green.shade200, // Adjusted color to match the image better
                icon: Icons.check_circle_outline_outlined,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const GoodStockPage()));
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded( // <--- Wrap each status button with Expanded
              child: _buildStatusButton(
                context,
                label: 'EXPIRING SOON',
                count: expiringSoonCount,
                color: Colors.yellow.shade200, // Adjusted color to match the image better
                icon: Icons.warning_amber,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const ExpiringSoonPage()));
                },
              ),
            ),
            const SizedBox(height: 20),
            Expanded( // <--- Wrap each status button with Expanded
              child: _buildStatusButton(
                context,
                label: 'EXPIRED STOCKS',
                count: expiredCount,
                color: Colors.red.shade200, // Adjusted color to match the image better
                icon: Icons.close,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const ExpiredStockPage()));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // *** MODIFIED METHOD: To match the card design from the image ***
  Widget _buildStatusButton(
      BuildContext context, {
        required String label,
        required int count,
        required Color color,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    // Determine a darker color for the count text
    final countColor = color.computeLuminance() > 0.5 ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(255, 0, 0, 0);

    return Card(
      elevation: 5, // Give it a slight shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: EdgeInsets.zero, // Use margin from the parent SizedBox
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.all(20),
          child: Stack( // Use Stack to position the count in the corner
            children: [
              // Main content centered
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      // Icon container to give it a white box look
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        icon,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Label at the bottom
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0), // Use black for contrast against bright card colors
                      ),
                    ),
                  ],
                ),
              ),
              
              // Count positioned in the top-right corner
              Positioned(
                top: 0,
                right: 0,
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: countColor, // Use computed color or a fixed black/white
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}