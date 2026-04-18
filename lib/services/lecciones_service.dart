import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class LeccionesService {
  static const String baseUrl = AppConfig.baseUrl;

  // Obtener token del almacenamiento local
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Obtener lecciones de un curso
  Future<Map<String, dynamic>> getLeccionesByCurso(int cursoId) async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = Uri.parse('$baseUrl/lecciones/curso/$cursoId');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Asegurarse de que data es una lista
        final lecciones = data is List ? data : [];
        return {
          'success': true,
          'lecciones': lecciones,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener las lecciones (${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener una lección por ID
  Future<Map<String, dynamic>> getLeccion(int leccionId) async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/lecciones/$leccionId'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'leccion': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener la lección',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }
}
