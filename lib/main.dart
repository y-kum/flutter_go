import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:async/async.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'all_submission.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Registration Form',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        textTheme: TextTheme(
          headline6: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
      home: RegistrationForm(),
    );
  }
}

class RegistrationForm extends StatefulWidget {
  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  DateTime? _selectedDate;
  File? _cvFile;
  String? _cvFileName;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registration Form'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
                validator: (value) => _validateName(value),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
                validator: (value) => _validateName(value),
              ),
              SizedBox(height: 20.0),
              GestureDetector(
                onTap: () async {
                  await _pickDate(context);
                },
                child: ListTile(
                  title: Text(
                    _selectedDate == null
                        ? 'Select Date of Birth'
                        : 'Date of Birth: ${_formatDate(_selectedDate!)}',
                  ),
                  trailing: Icon(Icons.calendar_today),
                ),
              ),
              SizedBox(height: 20.0),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) => _validateEmail(value),
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _phoneNumberController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone Number'),
                validator: (value) => _validatePhoneNumber(value),
              ),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: _uploadCV,
                child: Text('Upload CV (PDF/DOC)'),
              ),
              SizedBox(height: 16.0),
              Text(_cvFileName ?? ''),
              SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () => _submitForm(context),
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    // Custom validation to allow only uppercase and lowercase alphabets
    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(value)) {
      return 'Name can only contain alphabets';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!value.contains('@')) {
      return 'Invalid email';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    // You can also perform additional validation on phone number if needed
    return null;
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(), // Use _selectedDate or the current date if null
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && _calculateAge(picked) >= 18) {
      setState(() {
        _selectedDate = picked;
      });
    } else {
      // Show an error message if the selected date is invalid
      final snackBar = SnackBar(content: Text('Age should be at least 18'));
      _scaffoldKey.currentState!.showSnackBar(snackBar);
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  void _uploadCV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc']);
      if (result != null) {
        File file = File(result.files.single.path!);
        setState(() {
          _cvFile = file;
          _cvFileName = result.files.single.name;
        });
      } else {
        // User canceled the file picking
        return;
      }
    } catch (e) {
      print('Error uploading CV: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _submitForm(BuildContext context) async {
    if (_formKey.currentState?.validate() ?? false) {
      String firstName = _firstNameController.text;
      String lastName = _lastNameController.text;
      String dob = _selectedDate?.toIso8601String().split('T')[0] ?? '';
      String email = _emailController.text;
      String phoneNumber = _phoneNumberController.text;

      var formData = {
        'first_name': firstName,
        'last_name': lastName,
        'dob': dob,
        'email': email,
        'phone_number': phoneNumber,
        'cv_file_name': _cvFileName ?? '',
      };

      var jsonData = jsonEncode(formData);
      print(jsonData);

      try {
        var uri = Uri.parse('http://localhost:8081/submit');
        var request = http.MultipartRequest('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..fields.addAll(formData);

        if (_cvFile != null) {
          var stream = http.ByteStream(DelegatingStream.typed(_cvFile!.openRead()));
          var length = await _cvFile!.length();
          var multipartFile = http.MultipartFile('cv_file', stream, length, filename: basename(_cvFile!.path));
          request.files.add(multipartFile);
        }

        final response = await request.send();
        if (response.statusCode == 200) {
          print('Form submitted successfully');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SubmissionListPage()),
          );
        } else {
          print('Form submission failed with status code: ${response.statusCode}');
        }
      } catch (e) {
        print('Error submitting form: $e');
      }
    }
  }
}