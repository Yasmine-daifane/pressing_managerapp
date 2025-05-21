import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

void main() {
  runApp(MaterialApp(
    home: PressingManagerApp(),
    theme: ThemeData(
      colorScheme: ColorScheme.light(
        primary: Colors.orange,
        secondary: Colors.blueAccent,
      ),
    ),
  ));
}

class PressingManagerApp extends StatefulWidget {
  @override
  _PressingManagerAppState createState() => _PressingManagerAppState();
}

class _PressingManagerAppState extends State<PressingManagerApp> {
  final _formKey = GlobalKey<FormState>();
  final locationController = TextEditingController();
  final dateController = TextEditingController();
  final contactController = TextEditingController();
  final relanceController = TextEditingController();
  final nameController = TextEditingController();

  final List<String> cleaningTypes = [
    "Dry Cleaning",
    "Wash & Fold",
    "Iron Only",
    "Express Service"
  ];
  String? selectedCleaningType;
  bool isLoading = false;
  List<dynamic> suggestions = [];
  bool isSearching = false;

  @override
  void dispose() {
    locationController.dispose();
    dateController.dispose();
    contactController.dispose();
    relanceController.dispose();
    nameController.dispose();

    super.dispose();
  }

  Future<void> fetchLocationSuggestions(String input) async {
    setState(() => isSearching = true);
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$input&format=json&addressdetails=1&limit=5&countrycodes=ma');

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterPressingApp/1.0 (your_email@example.com)'
    });

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        suggestions = data;
        isSearching = false;
      });
    } else {
      setState(() => isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch locations.")),
      );
    }
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location services are disabled.")),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permission is denied.")),
        );
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final reverseUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');

    final response = await http.get(reverseUrl, headers: {
      'User-Agent': 'FlutterPressingApp/1.0 (your_email@example.com)'
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        locationController.text = data['display_name'] ?? 'Unknown location';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location name.")),
      );
    }
  }

  Future<void> saveToExcel() async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage permission is required.")),
      );
      return;
    }

    var excel = xls.Excel.createExcel();
    var sheet = excel['Sheet1'];

    sheet.appendRow([
      xls.TextCellValue("Location"),
      xls.TextCellValue("Cleaning Type"),
      xls.TextCellValue("Date"),
      xls.TextCellValue("Contact"),
      xls.TextCellValue("Relance")
    ]);

    sheet.appendRow([
      xls.TextCellValue(locationController.text),
      xls.TextCellValue(selectedCleaningType ?? ''),
      xls.TextCellValue(dateController.text),
      xls.TextCellValue(contactController.text),
      xls.TextCellValue(relanceController.text),
    ]);

    Directory? dir = await getExternalStorageDirectory();
    if (dir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to access storage directory.")),
      );
      return;
    }

    String formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String path = "${dir.path}/pressing_data_$formattedDate.xlsx";

    try {
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(excel.encode()!);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Saved to: $path")));
      _formKey.currentState!.reset();
      setState(() {
        selectedCleaningType = null;
        locationController.clear();
        dateController.clear();
        contactController.clear();
        relanceController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving file: $e")),
      );
    }
  }

  Future<void> _selectDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
      setState(() {
        dateController.text = formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pressing Manager")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔶 Location Box
            Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: locationController,
                            onChanged: fetchLocationSuggestions,
                            decoration: InputDecoration(
                              hintText: "Enter a location in Morocco",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.my_location,
                              color: Colors.orange),
                          onPressed: getCurrentLocation,
                          tooltip: "Use current location",
                        ),
                      ],
                    ),
                    if (isSearching) LinearProgressIndicator(),
                    ...suggestions.map((s) {
                      return ListTile(
                        title: Text(s['display_name']),
                        onTap: () {
                          locationController.text = s['display_name'];
                          setState(() => suggestions = []);
                        },
                      );
                    }).toList()
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            /// 🔷 Main Form Box
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _boxWrapper(
                    child: DropdownButtonFormField<String>(
                      value: selectedCleaningType,
                      decoration:
                      InputDecoration.collapsed(hintText: null),
                      hint: Text("Select Cleaning Type"),
                      items: cleaningTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => selectedCleaningType = val),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Required"
                          : null,
                    ),
                  ),
                  SizedBox(height: 20),
                  _boxWrapper(
                    child: TextFormField(
                      decoration: InputDecoration.collapsed(hintText: "Enter Client Name"),
                      validator: (value) => value == null || value.isEmpty ? "Required" : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  _boxWrapper(
                    child: TextFormField(
                      controller: dateController,
                      readOnly: true,
                      onTap: _selectDate,
                      decoration: InputDecoration.collapsed(
                          hintText: "Select Date of Visit"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Required"
                          : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  _boxWrapper(
                    child: TextFormField(
                      controller: contactController,
                      decoration: InputDecoration.collapsed(
                          hintText: "Enter Contact Info"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Required"
                          : null,
                    ),
                  ),
                  SizedBox(height: 10),
                  _boxWrapper(
                    child: TextFormField(
                      controller: relanceController,
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030),
                        );

                        if (pickedDate != null) {
                          String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
                          setState(() {
                            relanceController.text = formattedDate;
                          });
                        }
                      },
                      decoration: InputDecoration.collapsed(hintText: "Select Relance Date"),
                      validator: (value) =>
                      value == null || value.isEmpty ? "Required" : null,

                    ),
                  ),

                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        saveToExcel();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Save to Excel"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🧱 Box-styled input wrapper
  Widget _boxWrapper({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: child,
    );
  }
}
