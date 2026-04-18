import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;
  
  // Guardar token en almacenamiento local
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  // Obtener token del almacenamiento local
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Eliminar token (logout)
  Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String emailOrUsername,
    required String contrasena,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailOrUsername': emailOrUsername,
          'contrasena': contrasena,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Guardar token
        await saveToken(data['accessToken']);
        return {
          'success': true,
          'user': data['user'],
          'token': data['accessToken'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al iniciar sesión',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Registro
  Future<Map<String, dynamic>> register({
    required String nombreUsuario,
    required String email,
    required String contrasena,
    String? nombreCompleto,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombreUsuario': nombreUsuario,
          'email': email,
          'contrasena': contrasena,
          if (nombreCompleto != null && nombreCompleto.isNotEmpty)
            'nombreCompleto': nombreCompleto,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Guardar token
        await saveToken(data['accessToken']);
        return {
          'success': true,
          'user': data['user'],
          'token': data['accessToken'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al registrar usuario',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Verificar si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Obtener perfil del usuario
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener el perfil',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Actualizar perfil del usuario
  Future<Map<String, dynamic>> updateProfile({
    String? nombreCompleto,
    String? email,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay sesión activa',
        };
      }

      final body = <String, dynamic>{};
      if (nombreCompleto != null) {
        body['nombreCompleto'] = nombreCompleto;
      }
      if (email != null) {
        body['email'] = email;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar el perfil',
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
