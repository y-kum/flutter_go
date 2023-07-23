import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SubmissionListPage extends StatefulWidget {
  @override
  _SubmissionListPageState createState() => _SubmissionListPageState();
}

class _SubmissionListPageState extends State<SubmissionListPage> {
  List<dynamic> submissions = [];

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    // Replace the URL with your Golang backend endpoint that fetches the submissions
    final response = await http.get(Uri.parse('http://localhost:8081/submitted-forms'));

    if (response.statusCode == 200) {
      setState(() {
        // Convert the response body to a List of dynamic objects (assumes the backend returns a list of submissions)
        submissions = jsonDecode(response.body);
      });
    } else {
      // Handle error if the API request fails
      print('Failed to fetch submissions: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Submission List'),
      ),
      body: submissions.isEmpty
          ? Center(
              child: Text('No submitted forms yet.'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 8.0,
                dataRowHeight: 48.0,
                headingRowHeight: 56.0,
                columns: [
                  DataColumn(label: Text('Full Name')),
                  DataColumn(label: Text('DOB')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Phone Number')),
                  DataColumn(label: Text('View CV')),
                ],
                rows: submissions.map((submission) {
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        '${submission['first_name']} ${submission['last_name']}',
                        style: TextStyle(fontSize: 12.0), // Adjust font size here
                      )),
                      DataCell(Text(
                        formatDate(submission['dob']),
                        style: TextStyle(fontSize: 12.0), // Adjust font size here
                      )),
                      DataCell(Text(
                        submission['email'],
                        style: TextStyle(fontSize: 12.0), // Adjust font size here
                      )),
                      DataCell(Text(
                        submission['phone_number'],
                        style: TextStyle(fontSize: 12.0), // Adjust font size here
                      )),
                      DataCell(ElevatedButton(
                        onPressed: () async {
                          // Get the CV filename from the submission data
                          final cvFileName = submission['cv_file_name'];
                          // Encode the filename to make it URL-safe
                          final encodedFileName = Uri.encodeComponent(cvFileName);
                          // Construct the CV URL by appending the encoded filename to the base URL
                          final cvUrl = 'http://localhost:8081/cv/$encodedFileName';
                          // Open the CV URL in the browser
                          if (await canLaunch(cvUrl)) {
                            await launch(cvUrl);
                          } else {
                            print('Error launching URL: $cvUrl');
                          }
                        },
                        child: Text('View CV'),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  // Function to format the date to "dd/MM/yyyy" format
  String formatDate(String dateTimeStr) {
    final dateTime = DateTime.parse(dateTimeStr);
    final formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(dateTime);
  }
}