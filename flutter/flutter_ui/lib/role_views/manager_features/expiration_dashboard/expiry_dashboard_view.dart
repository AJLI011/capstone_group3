import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'good_stock_page.dart';
import 'expiring_soon_page.dart';
import 'expired_stock_page.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000/',
);

class ExpiryDashboardView extends StatefulWidget {
  const ExpiryDashboardView({super.key});

  @override
  State<ExpiryDashboardView> createState() => _ExpiryDashboardViewState();
}

class _ExpiryDashboardViewState extends State<ExpiryDashboardView> {
  int goodStockCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;

  final String baseUrl = '${API_BASE}api/medicines';

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
                color: Colors.greenAccent,
                icon: Icons.check_box,
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
                color: Colors.yellowAccent,
                icon: Icons.warning_amber_rounded,
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
                color: Colors.redAccent,
                icon: Icons.cancel,
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

  Widget _buildStatusButton(
      BuildContext context, {
        required String label,
        required int count,
        required Color color,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        // Remove fixed vertical padding here if it causes overflow, or reduce it.
        // It's better to let Expanded handle the vertical sizing.
        padding: const EdgeInsets.symmetric(vertical: 0), // Adjust or remove this if needed
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically within the expanded area
          children: [
            Icon(icon, size: 50),
            const SizedBox(height: 10),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}