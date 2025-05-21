import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/commercial_visit.dart';
import 'services/api_service.dart';

class PressingManagerApp extends StatefulWidget {
  @override
  _PressingManagerAppState createState( ) => _PressingManagerAppState();
}

class _PressingManagerAppState extends State<PressingManagerApp> {
  final _formKey = GlobalKey<FormState>();
  final locationController = TextEditingController();
  final dateController = TextEditingController();
  final contactController = TextEditingController();
  final relanceController = TextEditingController();
  final nameController = TextEditingController();
  final apiService = ApiService();

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
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final isLoggedIn = await apiService.isLoggedIn();
    if (!isLoggedIn) {
      // Si l'utilisateur n'est pas connecté, rediriger vers l'écran de connexion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

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
        'https://nominatim.openstreetmap.org/search?q=$input&format=json&addressdetails=1&limit=5&countrycodes=ma' );

    final response = await http.get(url, headers: {
      'User-Agent': 'FlutterPressingApp/1.0 (your_email@example.com )'
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
        'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json' );

    final response = await http.get(reverseUrl, headers: {
      'User-Agent': 'FlutterPressingApp/1.0 (your_email@example.com )'
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

  Future<void> saveVisit() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Récupérer l'utilisateur actuel
      final user = await apiService.getUser();
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Créer l'objet visite
      final visit = CommercialVisit(
        userId: user.id,
        clientName: nameController.text,
        location: locationController.text,
        cleaningType: selectedCleaningType ?? '',
        visitDate: dateController.text,
        contact: contactController.text,
        relanceDate: relanceController.text,
      );

      // Envoyer la visite à l'API
      final result = await apiService.createVisit(visit);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );

        // Réinitialiser le formulaire
        _formKey.currentState!.reset();
        setState(() {
          selectedCleaningType = null;
          locationController.clear();
          dateController.clear();
          contactController.clear();
          relanceController.clear();
          nameController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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

  Future<void> _logout() async {
    setState(() {
      isLoading = true;
    });

    try {
      final success = await apiService.logout();
      if (success) {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la déconnexion")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pressing Manager"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Déconnexion",
          ),
        ],
      ),
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
                      controller: nameController,
                      decoration: InputDecoration.collapsed(
                          hintText: "Enter Client Name"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Required"
                          : null,
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
                          String formattedDate =
                          DateFormat('yyyy-MM-dd').format(pickedDate);
                          setState(() {
                            relanceController.text = formattedDate;
                          });
                        }
                      },
                      decoration: InputDecoration.collapsed(
                          hintText: "Select Relance Date"),
                      validator: (value) =>
                      value == null || value.isEmpty
                          ? "Required"
                          : null,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        saveVisit();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text("Enregistrer la visite"),
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
