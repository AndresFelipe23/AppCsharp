import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class PracticasService {
  static const String baseUrl = AppConfig.baseUrl;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<Map<String, dynamic>> getAllPracticas() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/practicas/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final practicas = data is List ? data : [];
        return {'success': true, 'practicas': practicas};
      }

      return {
        'success': false,
        'message': data is Map ? (data['message'] ?? 'Error al obtener prácticas') : 'Error al obtener prácticas',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getPracticasByLeccion(int leccionId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/practicas/leccion/$leccionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final practicas = data is List ? data : [];
        return {'success': true, 'practicas': practicas};
      }

      return {
        'success': false,
        'message': data is Map ? (data['message'] ?? 'Error al obtener prácticas') : 'Error al obtener prácticas',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> getPractica(int practicaId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/practicas/$practicaId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'practica': data};
      }

      return {
        'success': false,
        'message': data is Map ? (data['message'] ?? 'Error al obtener la práctica') : 'Error al obtener la práctica',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>> validarRespuesta({
    required int practicaId,
    Map<String, dynamic>? multipleChoice,
    Map<String, dynamic>? completarCodigo,
    Map<String, dynamic>? escribirCodigo,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final body = <String, dynamic>{};
      if (multipleChoice != null) body['MultipleChoice'] = multipleChoice;
      if (completarCodigo != null) body['CompletarCodigo'] = completarCodigo;
      if (escribirCodigo != null) body['EscribirCodigo'] = escribirCodigo;

      // Validar que al menos un tipo de respuesta esté presente
      if (body.isEmpty) {
        return {
          'success': false,
          'message': 'No se proporcionó ninguna respuesta para validar',
        };
      }

      final bodyJson = jsonEncode(body);
      print('📤 Enviando validación: $bodyJson'); // Debug

      final response = await http.post(
        Uri.parse('$baseUrl/practicas/$practicaId/validar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: bodyJson,
      );

      print('📥 Respuesta del servidor: ${response.statusCode} - ${response.body}'); // Debug

      // Aceptar tanto 200 (OK) como 201 (Created) como respuestas exitosas
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'resultado': data};
      }

      // Manejar errores con más detalle
      String errorMessage = 'Error al validar respuesta (${response.statusCode})';
      
      try {
        final data = jsonDecode(response.body);
        
        if (data is Map) {
          // NestJS suele usar 'message' para errores
          if (data.containsKey('message')) {
            errorMessage = data['message'].toString();
          } 
          // Algunos errores vienen en 'error'
          else if (data.containsKey('error')) {
            final error = data['error'];
            if (error is String) {
              errorMessage = error;
            } else if (error is Map && error.containsKey('message')) {
              errorMessage = error['message'].toString();
            }
          }
          // Errores de validación pueden venir en un array
          else if (data.containsKey('statusCode') && data.containsKey('message')) {
            errorMessage = data['message'].toString();
          }
          // Errores de validación de class-validator
          else if (data.containsKey('statusCode') && data.containsKey('error')) {
            errorMessage = data['error'].toString();
          }
        } else if (data is String) {
          errorMessage = data;
        }
      } catch (e) {
        // Si no se puede parsear, usar el body raw
        if (response.body.isNotEmpty) {
          errorMessage = 'Error del servidor: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
        }
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }
}

