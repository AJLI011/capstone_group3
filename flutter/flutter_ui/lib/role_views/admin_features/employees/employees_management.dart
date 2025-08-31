import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:shared_preferences/shared_preferences.dart';


class EmployeesManagementPage extends StatefulWidget {
  const EmployeesManagementPage({super.key});

  @override
  State<EmployeesManagementPage> createState() => _EmployeesManagementPageState();
}

class _EmployeesManagementPageState extends State<EmployeesManagementPage> {
  List<dynamic> employees = [];

  @override
  void initState() {
    super.initState();
    fetchEmployees();
  }

  Future<void> fetchEmployees() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:8000/api/staff/'));
    if (response.statusCode == 200) {
      final List<dynamic> fetchedEmployees = json.decode(response.body);
      setState(() {
        // Filter out employees with the 'admin' role
        employees = fetchedEmployees.where((emp) => emp['role'] != 'admin').toList();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load employees')),
        );
      }
    }
  }

  Future<void> deleteEmployee(int id) async {
    final response = await http.delete(Uri.parse('http://10.0.2.2:8000/api/staff/$id/'));
    if (response.statusCode == 204) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
      }
      fetchEmployees(); // refresh list
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
      }
    }
  }

  void openAddEmployeeForm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EmployeeForm(onSuccess: fetchEmployees)),
    );
  }

  void openEditEmployeeForm(Map<String, dynamic> employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeForm(employee: employee, onSuccess: fetchEmployees),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: openAddEmployeeForm,
          )
        ],
      ),
      body: employees.isEmpty
          ? const Center(child: Text('No non-admin employees found'))
          : ListView.builder(
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final emp = employees[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(emp['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role: ${emp['role']}'),
                        Text('Contact: ${emp['contact_num']}'),
                        Text('Email: ${emp['email']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => openEditEmployeeForm(emp)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Delete'),
                                content: const Text('Do you want to remove this employee?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      deleteEmployee(emp['id']);
                                    },
                                    child: const Text('Yes'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------Employee Form Widget------------------

class EmployeeForm extends StatefulWidget {
  final Map<String, dynamic>? employee;
  final VoidCallback onSuccess;

  const EmployeeForm({super.key, this.employee, required this.onSuccess});

  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  final List<String> roles = ['manager', 'cashier', 'staff'];

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController contactController;
  late TextEditingController passwordController;
  String selectedRole = 'manager';

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.employee?['name'] ?? '');
    emailController = TextEditingController(text: widget.employee?['email'] ?? '');
    contactController = TextEditingController(text: widget.employee?['contact_num'] ?? '');
    passwordController = TextEditingController();
    selectedRole = widget.employee?['role'] ?? 'manager';
  }

  Future<void> saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.employee != null;
    final url = isEdit
        ? 'http://10.0.2.2:8000/api/staff/${widget.employee!['id']}/'
        : 'http://10.0.2.2:8000/api/staff/';

    final data = {
      'name': nameController.text,
      'email': emailController.text,
      'contact_num': contactController.text,
      'role': selectedRole,
    };

    if (!isEdit) {
      if (passwordController.text.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is required')));
        }
        return;
      } else {
        data['password'] = passwordController.text;
      }
    } else {
      if (passwordController.text.isNotEmpty) {
        data['password'] = passwordController.text;
      }
    }

    final response = await (isEdit
        ? http.put(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data))
        : http.post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data)));

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully')));
        widget.onSuccess();
        Navigator.pop(context);
      }
    } else {
      print('Error Response: ${response.body}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save')));
      }
    }
  }
  
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    contactController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add Staff Profile' : 'Edit Staff Profile'),
        backgroundColor: const Color(0xFF5C7C9A), // Updated color
        foregroundColor: Colors.white, // Updated color for font and icon
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextFormField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: contactController, decoration: const InputDecoration(labelText: 'Contact Number')),
              DropdownButtonFormField(
                value: selectedRole,
                items: roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                onChanged: (value) => setState(() => selectedRole = value!),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Confirm Save'),
                      content: const Text('Do you want to save changes?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    saveEmployee();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}