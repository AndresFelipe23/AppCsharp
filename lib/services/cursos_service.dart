import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class CursosService {
  static const String baseUrl = AppConfig.baseUrl;

  // Obtener token del almacenamiento local
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Obtener todas las rutas
  Future<Map<String, dynamic>> getRutas() async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/rutas'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'rutas': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener las rutas',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Rutas con cursos y lecciones anidadas en una sola petición (`GET /rutas/catalogo`).
  Future<Map<String, dynamic>> getCatalogo() async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/rutas/catalogo'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final rutas = _extractCatalogRutasList(data);
        return {
          'success': true,
          'rutas': rutas ?? <dynamic>[],
        };
      } else {
        final msg = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Error al obtener el catálogo';
        return {
          'success': false,
          'message': msg,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Acepta array raíz o envoltorio `{ data | rutas | Rutas: [...] }`.
  static List<dynamic>? _extractCatalogRutasList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final inner =
          m['data'] ?? m['rutas'] ?? m['Rutas'] ?? m['result'];
      if (inner is List) {
        return inner;
      }
    }
    return null;
  }

  // Obtener cursos de una ruta
  Future<Map<String, dynamic>> getCursosByRuta(int rutaId) async {
    try {
      final token = await getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/cursos/ruta/$rutaId'),
        headers: headers,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'cursos': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener los cursos',
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
