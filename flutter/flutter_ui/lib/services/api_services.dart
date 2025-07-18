//           COMMENTED MUNA, THIS IS API PARA DI NA NEED I HARCODE YUNG PAGPALIT
//           NG MGA IP FOR DEVICES
//           GAWIN NALANG TO PAG DEPLOYMENT NA OR SMTH
//
//
// // lib/services/api_service.dart

// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;

// class ApiService {
//   // This ensures only one instance of ApiService is created (Singleton pattern)
//   static final ApiService _instance = ApiService._internal();

//   factory ApiService() {
//     return _instance;
//   }

//   ApiService._internal();

//   // This is the core logic that determines the base URL
//   String get _apiBaseUrl {
//     // Check if running on Android (emulator or physical device) or iOS (simulator or physical device)
//     if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
//       if (Platform.isAndroid) {
//         // Android emulator uses 10.0.2.2 as an alias for the host machine's localhost (127.0.0.1)
//         return 'http://10.0.2.2:8000';
//       } else if (Platform.isIOS) {
//         // iOS simulator can typically access host machine via localhost or 127.0.0.1
//         return 'http://localhost:8000';
//       }
//     }
//     // Fallback for physical device (Android or iOS) or other platforms
//     // IMPORTANT: Replace with your computer's actual local IP address on your network!
//     // You can find this by running 'ipconfig' (Windows) or 'ifconfig'/'ip a' (macOS/Linux) in your terminal.
//     return 'http://192.168.0.103:8000'; // <--- **SET YOUR COMPUTER'S ACTUAL LOCAL IP HERE**
//   }

//   // --- API Methods ---

//   Future<http.Response> fetchSuppliers() async {
//     final url = Uri.parse('$_apiBaseUrl/api/suppliers/');
//     return await http.get(url);
//   }

//   Future<http.StreamedResponse> addMedicine(Map<String, String> fields, File? imageFile) async {
//     final url = Uri.parse('$_apiBaseUrl/api/medicines/');
//     final request = http.MultipartRequest('POST', url);

//     request.fields.addAll(fields); // Add all text fields from the map

//     if (imageFile != null) {
//       request.files.add(await http.MultipartFile.fromPath(
//         'image', // This must match the field name in your Django model (e.g., ImageField(upload_to='images/'))
//         imageFile.path,
//       ));
//     }
//     return await request.send();
//   }

//   // You would add more methods here for other API endpoints as your app grows:
//   // Future<http.Response> getMedicineDetails(int id) async { ... }
//   // Future<http.Response> deleteMedicine(int id) async { ... }
//   // Future<http.Response> updateMedicine(int id, Map<String, dynamic> data) async { ... }
// }

