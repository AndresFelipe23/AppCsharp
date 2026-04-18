import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ProgresoService {
  static const String baseUrl = AppConfig.baseUrl;

  /// Acepta `[1,2]`, números como double, strings, o `{ "leccionesIds": [...] }`.
  static List<int> _parseIdsLeccionesCompletadas(dynamic data) {
    dynamic raw = data;
    if (raw is Map) {
      raw = raw['leccionesIds'] ??
          raw['LeccionesIds'] ??
          raw['ids'] ??
          raw['data'];
    }
    if (raw is! List) return [];

    final out = <int>[];
    for (final e in raw) {
      if (e == null) continue;
      if (e is int) {
        if (e > 0) out.add(e);
        continue;
      }
      if (e is num) {
        final v = e.toInt();
        if (v > 0) out.add(v);
        continue;
      }
      final v = int.tryParse(e.toString());
      if (v != null && v > 0) out.add(v);
    }
    return out;
  }

  // Obtener token del almacenamiento local
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static const _prefVistaLeccionId = 'ultima_vista_leccion_id';
  static const _prefVistaCursoId = 'ultima_vista_curso_id';
  static const _prefVistaTitulo = 'ultima_vista_titulo';

  /// Última lección abierta en el dispositivo (refuerzo si el API va detrás del fallback).
  Future<void> guardarUltimaLeccionVista({
    required int leccionId,
    required int cursoId,
    required String titulo,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_prefVistaLeccionId, leccionId);
    await p.setInt(_prefVistaCursoId, cursoId);
    await p.setString(_prefVistaTitulo, titulo);
  }

  Future<Map<String, dynamic>?> leerUltimaLeccionVista() async {
    final p = await SharedPreferences.getInstance();
    final lid = p.getInt(_prefVistaLeccionId);
    final cid = p.getInt(_prefVistaCursoId);
    if (lid == null || cid == null || lid <= 0 || cid <= 0) return null;
    return {
      'leccionId': lid,
      'cursoId': cid,
      'titulo': p.getString(_prefVistaTitulo) ?? '',
    };
  }

  // Marcar lección como completada
  Future<Map<String, dynamic>> marcarLeccionCompletada(int leccionId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/progreso/lecciones/$leccionId/completar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'progreso': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al marcar la lección como completada',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Actualizar último acceso a lección
  Future<Map<String, dynamic>> actualizarUltimoAcceso(int leccionId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/progreso/lecciones/$leccionId/acceso'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'progreso': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar el último acceso',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener progreso de una lección específica
  Future<Map<String, dynamic>> obtenerProgresoLeccion(int leccionId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/lecciones/$leccionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Si no hay progreso, el backend devuelve un objeto con 'message'
        if (data.containsKey('message')) {
          return {
            'success': true,
            'progreso': null,
            'message': data['message'],
          };
        }
        return {
          'success': true,
          'progreso': data,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener el progreso',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener lista de IDs de lecciones completadas
  Future<Map<String, dynamic>> obtenerLeccionesCompletadas() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación', 'leccionesIds': []};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/lecciones/completadas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leccionesIds = _parseIdsLeccionesCompletadas(data);
        return {
          'success': true,
          'leccionesIds': leccionesIds,
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener las lecciones completadas',
          'leccionesIds': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
        'leccionesIds': [],
      };
    }
  }

  /// Última lección visitada y siguiente pendiente en ese curso (`GET .../lecciones/continuar`).
  Future<Map<String, dynamic>> obtenerSugerenciaContinuarLeccion() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/lecciones/continuar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        return {'success': false};
      }

      final data = jsonDecode(response.body);
      if (data == null || data is! Map) {
        return {'success': false};
      }

      final m = Map<String, dynamic>.from(data);
      final lid = m['leccionId'] ?? m['LeccionId'];
      if (lid == null) {
        return {'success': false};
      }

      return {
        'success': true,
        ...m,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// IDs de lecciones de [cursoId] ya completadas por el usuario (`GET .../cursos/:id/lecciones-completadas`).
  Future<Map<String, dynamic>> obtenerLeccionesCompletadasPorCurso(
    int cursoId,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'No hay token de autenticación',
          'leccionesIds': <int>[],
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/cursos/$cursoId/lecciones-completadas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leccionesIds = _parseIdsLeccionesCompletadas(data);
        return {
          'success': true,
          'leccionesIds': leccionesIds,
        };
      } else {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message': data is Map
                ? (data['message'] ?? 'Error al obtener lecciones del curso')
                : 'Error al obtener lecciones del curso',
            'leccionesIds': <int>[],
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Error al obtener lecciones del curso',
            'leccionesIds': <int>[],
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
        'leccionesIds': <int>[],
      };
    }
  }

  // Obtener estadísticas del usuario
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/estadisticas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'estadisticas': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener las estadísticas',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener progreso completo del usuario
  Future<Map<String, dynamic>> obtenerProgresoCompleto() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/completo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'progreso': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al obtener el progreso completo',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  // Obtener IDs de prácticas completadas
  Future<Map<String, dynamic>> obtenerPracticasCompletadas() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/practicas/completadas'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final practicaIds = data is List ? data.cast<int>() : <int>[];
        return {'success': true, 'practicaIds': practicaIds};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Error al obtener prácticas completadas') : 'Error al obtener prácticas completadas',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }

  // Obtener progreso de una práctica (incluye RespuestaUsuario si existe)
  Future<Map<String, dynamic>> obtenerProgresoPractica(int practicaId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No hay token de autenticación'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/progreso/practicas/$practicaId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'progreso': data};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data is Map ? (data['message'] ?? 'Error al obtener el progreso') : 'Error al obtener el progreso',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}'};
    }
  }
}
