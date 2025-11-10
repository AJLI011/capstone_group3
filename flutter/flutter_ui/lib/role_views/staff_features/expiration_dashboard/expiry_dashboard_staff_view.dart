import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'good_stock_staff_page.dart';
import 'expiring_soon_staff_page.dart';
import 'expired_stock_staff_page.dart';

class ExpiryDashboardStaffView extends StatefulWidget {
  const ExpiryDashboardStaffView({super.key});

  @override
  State<ExpiryDashboardStaffView> createState() => _ExpiryDashboardStaffViewState();
}

class _ExpiryDashboardStaffViewState extends State<ExpiryDashboardStaffView> {
  int goodStockCount = 0;
  int expiringSoonCount = 0;
  int expiredCount = 0;

  final String baseUrl = 'http://192.168.1.8:8000/api/medicines';

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
    setState(() {});
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
        setCount(0);
      }
    } catch (e) {
      print("Error fetching from $url: $e");
      setCount(0);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Flexible(
                flex: 1,
                child: _buildStatusButton(
                  label: 'GOOD STOCKS',
                  count: goodStockCount,
                  color: Colors.greenAccent,
                  icon: Icons.check_box,
                  onTap: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const GoodStockStaffPage()));
                  },
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                flex: 1,
                child: _buildStatusButton(
                  label: 'EXPIRING SOON',
                  count: expiringSoonCount,
                  color: Colors.yellowAccent,
                  icon: Icons.warning_amber_rounded,
                  onTap: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const ExpiringSoonStaffPage()));
                  },
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                flex: 1,
                child: _buildStatusButton(
                  label: 'EXPIRED STOCKS',
                  count: expiredCount,
                  color: Colors.redAccent,
                  icon: Icons.cancel,
                  onTap: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (context) => const ExpiredStockStaffPage()));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButton({
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
