import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/commercial_visit.dart';

class ApiService {
  // Remplacez par l'URL de votre API Laravel
  final String baseUrl = 'https://votre-api-laravel.com/api';
  final storage = FlutterSecureStorage( );

  // Méthode pour récupérer le token d'authentification
  Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }

  // Méthode pour sauvegarder le token d'authentification
  Future<void> saveToken(String token) async {
    await storage.write(key: 'auth_token', value: token);
  }

  // Méthode pour supprimer le token d'authentification
  Future<void> deleteToken() async {
    await storage.delete(key: 'auth_token');
  }

  // Méthode pour sauvegarder les informations de l'utilisateur
  Future<void> saveUser(User user) async {
    await storage.write(key: 'user_id', value: user.id.toString());
    await storage.write(key: 'user_name', value: user.name);
    await storage.write(key: 'user_email', value: user.email);
  }

  // Méthode pour récupérer l'utilisateur actuel
  Future<User?> getUser() async {
    final idStr = await storage.read(key: 'user_id');
    final name = await storage.read(key: 'user_name');
    final email = await storage.read(key: 'user_email');

    if (idStr != null && name != null && email != null) {
      return User(
        id: int.parse(idStr),
        name: name,
        email: email,
      );
    }
    return null;
  }

  // Méthode pour vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Méthode pour se connecter
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login' ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['token']);
      await saveUser(User.fromJson(data['user']));
      return {'success': true, 'message': data['message']};
    } else {
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Erreur de connexion'};
    }
  }

  // Méthode pour se déconnecter
  Future<bool> logout() async {
    final token = await getToken();
    if (token == null) return true;

    final response = await http.post(
      Uri.parse('$baseUrl/logout' ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      await deleteToken();
      return true;
    }
    return false;
  }

  // Méthode pour créer une visite commerciale
  Future<Map<String, dynamic>> createVisit(CommercialVisit visit) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Non authentifié'};
    }

    final response = await http.post(
      Uri.parse('$baseUrl/commercial-visits' ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(visit.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return {'success': true, 'message': data['message'], 'data': data['data']};
    } else {
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['message'] ?? 'Erreur lors de la création de la visite'};
    }
  }

  // Méthode pour récupérer les visites commerciales
  Future<List<CommercialVisit>> getVisits() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Non authentifié');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/commercial-visits' ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> visitsJson = data['data'];
      return visitsJson.map((json) => CommercialVisit.fromJson(json)).toList();
    } else {
      throw Exception('Erreur lors de la récupération des visites');
    }
  }
}
