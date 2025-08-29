import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Use dart-define to override in different environments
const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://aaron.pythonanywhere.com',
);

class EditCustomerProfilePage extends StatefulWidget {
  final int customerId;

  const EditCustomerProfilePage({super.key, required this.customerId});

  @override
  _EditCustomerProfilePageState createState() => _EditCustomerProfilePageState();
}

class _EditCustomerProfilePageState extends State<EditCustomerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure the widget is built before fetching data
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCustomerData());
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _fetchCustomerData() async {
    // Corrected URL to match standard REST conventions
    final url = Uri.parse('$API_BASE/api/customers/${widget.customerId}/');

    if (widget.customerId == 0) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Customer ID not found. Please log in again.');
      }
      return;
    }

    try {
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            nameController.text = data['name'] ?? '';
            contactController.text = data['contact_num'] ?? '';
            emailController.text = data['email'] ?? '';
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoading = false);
          _showErrorSnackBar('Failed to load profile data.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Something went wrong. Check your connection.');
      }
    }
  }

  Future<void> _saveProfile() async {
    final url = Uri.parse('$API_BASE/api/customers/${widget.customerId}/');
    final body = json.encode({
      'email': emailController.text.trim(),
      'name': nameController.text.trim(),
      'contact_num': contactController.text.trim(),
    });

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('customerName', nameController.text.trim());
        await prefs.setString('customerEmail', emailController.text.trim());

        if (mounted) {
          _showSuccessSnackBar('Profile updated successfully!');
          Navigator.pop(context, true);
        }
      } else {
        final data = json.decode(response.body);
        _showErrorSnackBar(data['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('Something went wrong');
    }
  }

  Future<void> _confirmSaveProfile() async {
    if (_formKey.currentState!.validate()) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Save'),
          content: const Text('Are you sure you want to save these changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        _saveProfile();
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color.fromARGB(255, 10, 84, 182), //a dded color
        foregroundColor: Colors.white, //changed font color
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: contactController,
                      decoration: const InputDecoration(labelText: "Contact Number"),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      readOnly: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _confirmSaveProfile,
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}