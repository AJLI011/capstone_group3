import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditManagerProfilePage extends StatefulWidget {
  final int staffId;

  const EditManagerProfilePage({super.key, required this.staffId});

  @override
  _EditManagerProfilePageState createState() => _EditManagerProfilePageState();
}

class _EditManagerProfilePageState extends State<EditManagerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController roleController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchManagerData();
  }

  void fetchManagerData() async {
    final response = await http.get(
      Uri.parse('http://10.0.2.2:8000/api/staff/${widget.staffId}/profile/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        nameController.text = data['name'] ?? '';
        contactController.text = data['contact_num'] ?? '';
        emailController.text = data['email'] ?? '';
        roleController.text = data['role'] ?? 'manager';
        isLoading = false;
      });
    } else {
      print('Failed to load manager data: ${response.statusCode}');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile data')),
      );
    }
  }

  Future<void> saveProfile() async {
    final url = Uri.parse('http://juliaally.pythonanywhere.com/api/staff/${widget.staffId}/update-profile/');
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
        final data = json.decode(response.body);
        final updatedStaffData = data['staff'];

        if (updatedStaffData != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', updatedStaffData['name'] ?? nameController.text.trim());
          await prefs.setString('email', updatedStaffData['email'] ?? emailController.text.trim());
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update profile')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
      print('Error: $e');
    }
  }

  Future<void> _confirmSaveProfile() async {
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
      saveProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
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
                      decoration: const InputDecoration(labelText: "Contact"),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: roleController,
                      decoration: const InputDecoration(labelText: "Role"),
                      readOnly: true,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      readOnly: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _confirmSaveProfile();
                        }
                      },
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
