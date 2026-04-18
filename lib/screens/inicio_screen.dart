import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/cursos_service.dart';
import '../services/auth_service.dart';
import '../services/lecciones_service.dart';
import '../services/progreso_service.dart';
import 'lecciones_screen.dart';
import 'leccion_detalle_screen.dart';

typedef _FiltroCatalogoFn = ({
  List<dynamic> rutasFiltradas,
  Map<int, List<dynamic>> cursosFiltradosPorRuta,
  List<dynamic> leccionesFiltradas,
}) Function(
  String query,
  List<dynamic> rutas,
  Map<int, List<dynamic>> cursosPorRuta,
  Map<int, List<dynamic>> leccionesPorCurso,
);

typedef _LeccionCardBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> leccion, {
  void Function(void Function() navegar)? alAbrir,
  BuildContext? contextoNavegacion,
});

typedef _CursoCardBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> curso, {
  void Function(void Function() navegar)? alAbrir,
  BuildContext? contextoNavegacion,
});

typedef _RutaSectionBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> ruta,
  List<dynamic> cursos, {
  void Function(void Function() navegar)? alAbrirCurso,
  BuildContext? contextoNavegacion,
});

int? _coerceIntTop(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with SingleTickerProviderStateMixin {
  final _cursosService = CursosService();
  final _authService = AuthService();
  final _leccionesService = LeccionesService();
  final _progresoService = ProgresoService();
  List<dynamic> _rutas = [];
  final Map<int, List<dynamic>> _cursosPorRuta = {};
  final Map<int, List<dynamic>> _leccionesPorCurso = {};
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _progresoCompleto;
  Set<int> _leccionesCompletadasIds = {};
  Map<String, dynamic>? _siguienteLeccion;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Resultado de filtrar catálogo (reutilizado en el modal de búsqueda).
  ({
    List<dynamic> rutasFiltradas,
    Map<int, List<dynamic>> cursosFiltradosPorRuta,
    List<dynamic> leccionesFiltradas,
  }) _filtrarCatalogo(
    String query,
    List<dynamic> rutas,
    Map<int, List<dynamic>> cursosPorRuta,
    Map<int, List<dynamic>> leccionesPorCurso,
  ) {
    if (query.trim().isEmpty) {
      return (
        rutasFiltradas: List<dynamic>.from(rutas),
        cursosFiltradosPorRuta: Map<int, List<dynamic>>.from(cursosPorRuta),
        leccionesFiltradas: <dynamic>[],
      );
    }

    final queryLower = query.toLowerCase();
    final rutasFiltradas = <dynamic>[];
    final cursosFiltradosPorRuta = <int, List<dynamic>>{};
    final leccionesFiltradas = <dynamic>[];

    for (var ruta in rutas) {
      if (ruta is! Map) continue;
      final rutaMap = Map<String, dynamic>.from(ruta);
      final rutaKey = _coerceInt(rutaMap['RutaId'] ?? rutaMap['rutaId']);
      if (rutaKey == null) continue;

      final nombreRuta =
          (rutaMap['Nombre'] ?? rutaMap['nombre'] ?? '').toString().toLowerCase();
      final descripcionRuta =
          (rutaMap['Descripcion'] ?? rutaMap['descripcion'] ?? '')
              .toString()
              .toLowerCase();

      final rutaCoincide =
          nombreRuta.contains(queryLower) ||
          descripcionRuta.contains(queryLower);

      final cursos = cursosPorRuta[rutaKey] ?? [];
      final cursosFiltrados = cursos.where((curso) {
        if (curso is! Map) return false;
        final cm = Map<String, dynamic>.from(curso);
        final nombreCurso =
            (cm['Nombre'] ?? cm['nombre'] ?? '').toString().toLowerCase();
        final descripcionCurso =
            (cm['Descripcion'] ?? cm['descripcion'] ?? '')
                .toString()
                .toLowerCase();
        return nombreCurso.contains(queryLower) ||
            descripcionCurso.contains(queryLower);
      }).toList();

      for (var curso in cursos) {
        if (curso is! Map) continue;
        final cursosMap = Map<String, dynamic>.from(curso);
        final cursoId =
            _coerceInt(cursosMap['CursoId'] ?? cursosMap['cursoId']);
        if (cursoId == null) continue;
        final lecciones = leccionesPorCurso[cursoId] ?? [];
        final leccionesDelCurso = lecciones.where((leccion) {
          final titulo = (leccion['Titulo'] ?? leccion['titulo'] ?? '')
              .toLowerCase();
          final descripcion =
              (leccion['DescripcionCorta'] ??
                      leccion['descripcionCorta'] ??
                      '')
                  .toLowerCase();
          return titulo.contains(queryLower) ||
              descripcion.contains(queryLower);
        }).toList();

        for (var leccion in leccionesDelCurso) {
          leccionesFiltradas.add({
            ...leccion,
            'cursoId': cursoId,
            'cursoNombre':
                cursosMap['Nombre'] ?? cursosMap['nombre'] ?? 'Curso sin nombre',
            'rutaId': rutaKey,
            'rutaNombre':
                rutaMap['Nombre'] ?? rutaMap['nombre'] ?? 'Ruta sin nombre',
          });
        }
      }

      if (rutaCoincide || cursosFiltrados.isNotEmpty) {
        rutasFiltradas.add(ruta);
        cursosFiltradosPorRuta[rutaKey] = cursosFiltrados;
      }
    }

    return (
      rutasFiltradas: rutasFiltradas,
      cursosFiltradosPorRuta: cursosFiltradosPorRuta,
      leccionesFiltradas: leccionesFiltradas,
    );
  }

  int? _coerceInt(dynamic v) => _coerceIntTop(v);

  List<dynamic> _listFromMap(Map<String, dynamic> m, String pascal, String camel) {
    final v = m[pascal] ?? m[camel];
    return v is List ? v : [];
  }

  /// Aplana el JSON de `/rutas/catalogo` al estado que usa búsqueda y tarjetas.
  /// Acepta claves PascalCase o camelCase y fija `RutaId` / `CursoId` para el resto de la UI.
  ({
    List<dynamic> rutas,
    Map<int, List<dynamic>> cursosPorRuta,
    Map<int, List<dynamic>> leccionesPorCurso,
  }) _parseCatalog(List<dynamic> rawRutas) {
    final rutas = <dynamic>[];
    final cursosPorRuta = <int, List<dynamic>>{};
    final leccionesPorCurso = <int, List<dynamic>>{};

    for (final raw in rawRutas) {
      if (raw is! Map) continue;
      final src = Map<String, dynamic>.from(raw);
      final cursosSrc = _listFromMap(src, 'Cursos', 'cursos');

      final rid = _coerceInt(src['RutaId'] ?? src['rutaId']);
      if (rid == null) continue;

      final ruta = Map<String, dynamic>.from(src);
      ruta.remove('Cursos');
      ruta.remove('cursos');
      ruta['RutaId'] = rid;
      ruta['rutaId'] = rid;

      final descRuta = ruta['DescripcionCorta'] ?? ruta['descripcionCorta'];
      if (descRuta != null) {
        ruta['Descripcion'] = descRuta;
      }

      final cursos = <dynamic>[];
      for (final rawCurso in cursosSrc) {
        if (rawCurso is! Map) continue;
        final cs0 = Map<String, dynamic>.from(rawCurso);
        final leccionesSrc = _listFromMap(cs0, 'Lecciones', 'lecciones');

        final cid = _coerceInt(cs0['CursoId'] ?? cs0['cursoId']);
        if (cid == null) continue;

        final curso = Map<String, dynamic>.from(cs0);
        curso.remove('Lecciones');
        curso.remove('lecciones');
        curso['CursoId'] = cid;
        curso['cursoId'] = cid;
        curso['RutaId'] = curso['RutaId'] ?? curso['rutaId'] ?? rid;
        curso['rutaId'] = curso['RutaId'];

        final descCurso =
            curso['DescripcionCorta'] ?? curso['descripcionCorta'];
        if (descCurso != null) {
          curso['Descripcion'] = descCurso;
        }
        curso['Lecciones'] = leccionesSrc;

        final lecciones = <Map<String, dynamic>>[];
        for (final l in leccionesSrc) {
          if (l is! Map) continue;
          lecciones.add(Map<String, dynamic>.from(l));
        }
        leccionesPorCurso[cid] = lecciones;

        cursos.add(curso);
      }

      rutas.add(ruta);
      cursosPorRuta[rid] = cursos;
    }

    return (
      rutas: rutas,
      cursosPorRuta: cursosPorRuta,
      leccionesPorCurso: leccionesPorCurso,
    );
  }

  Future<void> _loadDataLegacy() async {
    final rutasResult = await _cursosService.getRutas();
    if (rutasResult['success'] != true) return;

    final rutasRaw = rutasResult['rutas'];
    if (rutasRaw is! List) return;

    final cursosPorRuta = <int, List<dynamic>>{};
    final leccionesPorCurso = <int, List<dynamic>>{};

    for (final rawRuta in rutasRaw) {
      if (rawRuta is! Map) continue;
      final ruta = Map<String, dynamic>.from(rawRuta);
      final rid = _coerceInt(ruta['RutaId'] ?? ruta['rutaId']);
      if (rid == null) continue;

      final cursosResult = await _cursosService.getCursosByRuta(rid);
      if (cursosResult['success'] != true) continue;

      final cursos = cursosResult['cursos'] as List? ?? [];
      cursosPorRuta[rid] = cursos;

      for (final curso in cursos) {
        if (curso is! Map) continue;
        final cm = Map<String, dynamic>.from(curso);
        final cid = _coerceInt(cm['CursoId'] ?? cm['cursoId']);
        if (cid == null) continue;

        final leccionesResult =
            await _leccionesService.getLeccionesByCurso(cid);
        if (leccionesResult['success'] == true &&
            leccionesResult['lecciones'] != null) {
          leccionesPorCurso[cid] = leccionesResult['lecciones'] as List;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _rutas = rutasRaw;
      _cursosPorRuta
        ..clear()
        ..addAll(cursosPorRuta);
      _leccionesPorCurso
        ..clear()
        ..addAll(leccionesPorCurso);
    });
  }

  Map<String, dynamic>? _estadisticasProgreso() {
    final root = _progresoCompleto;
    if (root == null) return null;
    final e = root['estadisticas'] ?? root['Estadisticas'];
    return e is Map<String, dynamic> ? e : null;
  }

  int _cursosConLeccionesEnProgreso() {
    final raw = _progresoCompleto?['progresoCursos'] ??
        _progresoCompleto?['ProgresoCursos'];
    if (raw is! List) return 0;
    var n = 0;
    for (final c in raw) {
      if (c is! Map) continue;
      final lc = _coerceInt(c['leccionesCompletadas'] ?? c['LeccionesCompletadas']) ?? 0;
      final tl = _coerceInt(c['totalLecciones'] ?? c['TotalLecciones']) ?? 0;
      if (tl > 0 && lc > 0 && lc < tl) n++;
    }
    return n;
  }

  List<Map<String, dynamic>> _leccionesOrdenadas(int cursoId) {
    final raw = _leccionesPorCurso[cursoId] ?? [];
    final list = <Map<String, dynamic>>[];
    for (final l in raw) {
      if (l is Map) list.add(Map<String, dynamic>.from(l));
    }
    list.sort((a, b) {
      final oa = _coerceInt(a['Orden'] ?? a['orden']) ?? 0;
      final ob = _coerceInt(b['Orden'] ?? b['orden']) ?? 0;
      return oa.compareTo(ob);
    });
    return list;
  }

  int? _idLeccionCatalogo(Map<String, dynamic> leccion) {
    return _coerceInt(
      leccion['LeccionId'] ??
          leccion['leccionId'] ??
          leccion['ID'] ??
          leccion['id'] ??
          leccion['Id'],
    );
  }

  /// Alineado con la lista de lecciones: incluye IDs por curso desde `progreso/completo`.
  void _mergeCompletadasIdsDesdeProgresoCursos() {
    final raw = _progresoCompleto?['progresoCursos'] ??
        _progresoCompleto?['ProgresoCursos'];
    if (raw is! List) return;
    for (final c in raw) {
      if (c is! Map) continue;
      final m = Map<String, dynamic>.from(c);
      final idsRaw =
          m['leccionesCompletadasIds'] ?? m['LeccionesCompletadasIds'];
      if (idsRaw is! List) continue;
      for (final e in idsRaw) {
        final id = e is int
            ? e
            : (e is num ? e.toInt() : int.tryParse(e.toString()));
        if (id != null && id > 0) _leccionesCompletadasIds.add(id);
      }
    }
  }

  /// Si el backend indica curso al 100 %, no ofrecer ninguna lección de ese curso como “siguiente”.
  bool _cursoCompletadoSegunProgresoCompleto(int cursoId) {
    final raw = _progresoCompleto?['progresoCursos'] ??
        _progresoCompleto?['ProgresoCursos'];
    if (raw is! List) return false;
    for (final c in raw) {
      if (c is! Map) continue;
      final m = Map<String, dynamic>.from(c);
      final cid = _coerceInt(m['cursoId'] ?? m['CursoId']);
      if (cid != cursoId) continue;
      final lc =
          _coerceInt(m['leccionesCompletadas'] ?? m['LeccionesCompletadas']) ??
              0;
      final tl =
          _coerceInt(m['totalLecciones'] ?? m['TotalLecciones']) ?? 0;
      return tl > 0 && lc >= tl;
    }
    return false;
  }

  /// Curso con al menos una lección hecha y aún faltan (prioridad para el fallback).
  bool _cursoEnProgresoParcial(int cursoId) {
    final raw = _progresoCompleto?['progresoCursos'] ??
        _progresoCompleto?['ProgresoCursos'];
    if (raw is! List) return false;
    for (final c in raw) {
      if (c is! Map) continue;
      final m = Map<String, dynamic>.from(c);
      final cid = _coerceInt(m['cursoId'] ?? m['CursoId']);
      if (cid != cursoId) continue;
      final lc =
          _coerceInt(m['leccionesCompletadas'] ?? m['LeccionesCompletadas']) ??
              0;
      final tl =
          _coerceInt(m['totalLecciones'] ?? m['TotalLecciones']) ?? 0;
      return tl > 0 && lc > 0 && lc < tl;
    }
    return false;
  }

  int? _ordenLeccionEnCatalogo(int cursoId, int leccionId) {
    for (final l in _leccionesOrdenadas(cursoId)) {
      if (_idLeccionCatalogo(l) == leccionId) {
        return _coerceInt(l['Orden'] ?? l['orden']);
      }
    }
    return null;
  }

  String _tituloLeccionEnCatalogo(
    int cursoId,
    int leccionId,
    String fallback,
  ) {
    for (final l in _leccionesOrdenadas(cursoId)) {
      if (_idLeccionCatalogo(l) == leccionId) {
        final t = l['Titulo'] ?? l['titulo'];
        if (t != null && t.toString().trim().isNotEmpty) {
          return t.toString();
        }
      }
    }
    return fallback;
  }

  Map<String, dynamic> _tarjetaContinuarEnriquecida(
    int leccionId,
    int cursoId,
    String tituloFallback,
  ) {
    String rutaNombre = '';
    String cursoNombre = '';
    for (final ruta in _rutas) {
      if (ruta is! Map) continue;
      final rutaMap = Map<String, dynamic>.from(ruta);
      final rutaKey = _coerceInt(rutaMap['RutaId'] ?? rutaMap['rutaId']);
      if (rutaKey == null) continue;
      final rn =
          rutaMap['Nombre'] ?? rutaMap['nombre'] ?? 'Ruta sin nombre';
      final cursos = _cursosPorRuta[rutaKey] ?? [];
      for (final curso in cursos) {
        if (curso is! Map) continue;
        final cm = Map<String, dynamic>.from(curso);
        final cid = _coerceInt(cm['CursoId'] ?? cm['cursoId']);
        if (cid != cursoId) continue;
        cursoNombre =
            (cm['Nombre'] ?? cm['nombre'] ?? 'Curso sin nombre').toString();
        rutaNombre = rn.toString();
        break;
      }
    }
    final titulo =
        _tituloLeccionEnCatalogo(cursoId, leccionId, tituloFallback);
    return {
      'leccionId': leccionId,
      'cursoId': cursoId,
      'titulo': titulo,
      'cursoNombre': cursoNombre,
      'rutaNombre': rutaNombre,
    };
  }

  Future<void> _preferirUltimaLeccionVistaLocal() async {
    final local = await _progresoService.leerUltimaLeccionVista();
    if (local == null) return;
    final lid = _coerceInt(local['leccionId']);
    final cid = _coerceInt(local['cursoId']);
    if (lid == null || cid == null) return;
    if (_leccionesCompletadasIds.contains(lid)) return;
    if (_cursoCompletadoSegunProgresoCompleto(cid)) return;

    final localOrden = _ordenLeccionEnCatalogo(cid, lid);
    if (localOrden == null) return;

    final tituloG = (local['titulo'] ?? '').toString();

    if (_siguienteLeccion == null) {
      _siguienteLeccion =
          _tarjetaContinuarEnriquecida(lid, cid, tituloG);
      return;
    }

    final curLid = _coerceInt(_siguienteLeccion!['leccionId']);
    final curCid = _coerceInt(_siguienteLeccion!['cursoId']);
    if (curLid == null || curCid == null) return;

    if (cid != curCid) {
      if (_cursoEnProgresoParcial(cid) && !_cursoEnProgresoParcial(curCid)) {
        _siguienteLeccion =
            _tarjetaContinuarEnriquecida(lid, cid, tituloG);
      }
      return;
    }

    final curOrden = _ordenLeccionEnCatalogo(curCid, curLid);
    if (curOrden == null) return;
    if (localOrden > curOrden) {
      _siguienteLeccion =
          _tarjetaContinuarEnriquecida(lid, cid, tituloG);
    }
  }

  void _recalcSiguienteLeccion() {
    final entries = <Map<String, dynamic>>[];
    var orden = 0;
    for (final ruta in _rutas) {
      if (ruta is! Map) continue;
      final rutaMap = Map<String, dynamic>.from(ruta);
      final rutaKey = _coerceInt(rutaMap['RutaId'] ?? rutaMap['rutaId']);
      if (rutaKey == null) continue;
      final rutaNombre =
          rutaMap['Nombre'] ?? rutaMap['nombre'] ?? 'Ruta sin nombre';
      final cursos = _cursosPorRuta[rutaKey] ?? [];
      for (final curso in cursos) {
        if (curso is! Map) continue;
        final cm = Map<String, dynamic>.from(curso);
        final cursoId = _coerceInt(cm['CursoId'] ?? cm['cursoId']);
        if (cursoId == null) continue;
        final cursoNombre = cm['Nombre'] ?? cm['nombre'] ?? 'Curso sin nombre';
        entries.add({
          'cursoId': cursoId,
          'rutaNombre': rutaNombre,
          'cursoNombre': cursoNombre,
          'parcial': _cursoEnProgresoParcial(cursoId),
          'orden': orden++,
        });
      }
    }

    entries.sort((a, b) {
      final pa = a['parcial'] == true;
      final pb = b['parcial'] == true;
      if (pa != pb) {
        return pa ? -1 : 1;
      }
      return (a['orden'] as int).compareTo(b['orden'] as int);
    });

    for (final e in entries) {
      final cursoId = e['cursoId'] as int;
      if (_cursoCompletadoSegunProgresoCompleto(cursoId)) continue;
      final rutaNombre = e['rutaNombre'] as String;
      final cursoNombre = e['cursoNombre'] as String;
      for (final leccion in _leccionesOrdenadas(cursoId)) {
        final inactiva =
            leccion['Activo'] == false || leccion['activo'] == false;
        if (inactiva) continue;
        final lid = _idLeccionCatalogo(leccion);
        if (lid == null) continue;
        if (!_leccionesCompletadasIds.contains(lid)) {
          _siguienteLeccion = {
            'leccionId': lid,
            'titulo':
                leccion['Titulo'] ?? leccion['titulo'] ?? 'Lección sin nombre',
            'cursoId': cursoId,
            'cursoNombre': cursoNombre,
            'rutaNombre': rutaNombre,
          };
          return;
        }
      }
    }
    _siguienteLeccion = null;
  }

  String _primerNombreUsuario() {
    final n = _userData?['nombreCompleto']?.toString().trim() ?? '';
    if (n.isEmpty) return 'Aprendiz';
    return n.split(RegExp(r'\s+')).first;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final parallel = await Future.wait([
      _cursosService.getCatalogo(),
      _authService.getProfile(),
      _progresoService.obtenerProgresoCompleto(),
      _progresoService.obtenerLeccionesCompletadas(),
      _progresoService.obtenerSugerenciaContinuarLeccion(),
    ]);

    final catalogResult = parallel[0];
    final userResult = parallel[1];
    final progresoResult = parallel[2];
    final completadasResult = parallel[3];
    final continuarResult = parallel[4];

    if (!mounted) return;

    if (userResult['success'] == true && userResult['user'] != null) {
      _userData = userResult['user'] as Map<String, dynamic>;
    }

    if (progresoResult['success'] == true && progresoResult['progreso'] != null) {
      _progresoCompleto = progresoResult['progreso'] as Map<String, dynamic>;
    } else {
      _progresoCompleto = null;
    }

    if (completadasResult['success'] == true &&
        completadasResult['leccionesIds'] is List) {
      _leccionesCompletadasIds = (completadasResult['leccionesIds'] as List)
          .map((e) {
            if (e is int) return e;
            if (e is num) return e.toInt();
            return int.tryParse(e.toString()) ?? 0;
          })
          .where((id) => id > 0)
          .toSet();
    } else {
      _leccionesCompletadasIds = {};
    }
    _mergeCompletadasIdsDesdeProgresoCursos();

    var catalogOk = false;
    try {
      if (catalogResult['success'] == true &&
          catalogResult['rutas'] is List) {
        final p = _parseCatalog(catalogResult['rutas'] as List);
        _rutas = p.rutas;
        _cursosPorRuta
          ..clear()
          ..addAll(p.cursosPorRuta);
        _leccionesPorCurso
          ..clear()
          ..addAll(p.leccionesPorCurso);
        catalogOk = true;
      }
    } catch (_) {
      catalogOk = false;
    }

    if (!catalogOk) {
      await _loadDataLegacy();
    }

    void aplicarContinuarDesdeMap(dynamic raw) {
      if (raw is! Map) return;
      final m = Map<String, dynamic>.from(raw);
      final lid = _coerceInt(m['leccionId'] ?? m['LeccionId']);
      final cid = _coerceInt(m['cursoId'] ?? m['CursoId']);
      if (lid == null || cid == null || lid <= 0 || cid <= 0) return;
      _siguienteLeccion = {
        'leccionId': lid,
        'titulo': m['titulo'] ?? m['Titulo'] ?? 'Lección',
        'cursoId': cid,
        'cursoNombre': m['cursoNombre'] ?? m['CursoNombre'] ?? '',
        'rutaNombre': m['rutaNombre'] ?? m['RutaNombre'] ?? '',
      };
    }

    _siguienteLeccion = null;
    // Misma sugerencia que el GET /continuar, incluida en progreso/completo (sirve en producción al desplegar API).
    aplicarContinuarDesdeMap(
      _progresoCompleto?['continuarLeccion'] ??
          _progresoCompleto?['ContinuarLeccion'],
    );
    if (_siguienteLeccion == null && continuarResult['success'] == true) {
      aplicarContinuarDesdeMap(continuarResult);
    }
    if (_siguienteLeccion == null) {
      _recalcSiguienteLeccion();
    }
    await _preferirUltimaLeccionVistaLocal();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    _animationController.forward(from: 0);
  }

  void _abrirBusqueda() {
    final ctxNav = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BusquedaInicioSheet(
        contextoPrincipal: ctxNav,
        filtrar: _filtrarCatalogo,
        rutas: _rutas,
        cursosPorRuta: _cursosPorRuta,
        leccionesPorCurso: _leccionesPorCurso,
        buildLeccionCard: (c, m, {alAbrir, contextoNavegacion}) =>
            _buildLeccionCard(
              c,
              m,
              alAbrir: alAbrir,
              contextoNavegacion: contextoNavegacion,
            ),
        buildCursoCard: (c, m, {alAbrir, contextoNavegacion}) =>
            _buildCursoCard(
              c,
              m,
              alAbrir: alAbrir,
              contextoNavegacion: contextoNavegacion,
            ),
        buildRutaSection: (c, r, l, {alAbrirCurso, contextoNavegacion}) =>
            _buildRutaSection(
              c,
              r,
              l,
              alAbrirCurso: alAbrirCurso,
              contextoNavegacion: contextoNavegacion,
            ),
        buildNoResults: _buildNoResultsState,
      ),
    );
  }

  int _statLeccionesCompletadas() {
    final est = _estadisticasProgreso();
    final v = est?['leccionesCompletadas'] ?? est?['LeccionesCompletadas'];
    return _coerceInt(v) ?? 0;
  }

  int _statPuntos() {
    final est = _estadisticasProgreso();
    final v = est?['puntosTotales'] ?? est?['PuntosTotales'];
    if (v != null) return _coerceInt(v) ?? 0;
    return _coerceInt(_userData?['puntosTotales']) ?? 0;
  }

  Widget _buildEncabezadoInicio(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryLight,
            AppTheme.accentColor,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${_primerNombreUsuario()}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Retoma tu ruta o explora el catálogo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.88),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _abrirBusqueda,
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.18),
            ),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Buscar',
          ),
          const SizedBox(width: 4),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.45)),
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.code_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaContinuar(BuildContext context) {
    final s = _siguienteLeccion;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded,
                  color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 10),
              Text(
                s != null ? 'Continúa donde quedaste' : 'Tu siguiente paso',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (s != null) ...[
            Text(
              '${s['titulo']}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${s['rutaNombre']} · ${s['cursoNombre']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final lid = _coerceInt(s['leccionId']);
                final cid = _coerceInt(s['cursoId']);
                if (lid == null || cid == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => LeccionDetalleScreen(
                      leccionId: lid,
                      leccionTitulo: '${s['titulo']}',
                      cursoId: cid,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Ir a la lección'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ] else if (_rutas.isNotEmpty) ...[
            Text(
              'Has completado las lecciones disponibles en el catálogo, o aún no hay contenido nuevo para ti.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _abrirBusqueda,
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explorar catálogo'),
            ),
          ] else
            Text(
              'Cuando haya rutas publicadas aparecerán aquí.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumenMetricas(BuildContext context) {
    final cursosActivos = _cursosConLeccionesEnProgreso();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            context,
            icon: Icons.check_circle_rounded,
            label: 'Lecciones',
            value: '${_statLeccionesCompletadas()}',
            color: AppTheme.successColor,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade200,
          ),
          _buildStatItem(
            context,
            icon: Icons.hourglass_top_rounded,
            label: 'Cursos activos',
            value: '$cursosActivos',
            color: AppTheme.primaryColor,
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey.shade200,
          ),
          _buildStatItem(
            context,
            icon: Icons.star_rounded,
            label: 'Puntos',
            value: '${_statPuntos()}',
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildRutaAcordeon(BuildContext context, int index) {
    final ruta = _rutas[index];
    if (ruta is! Map) return const SizedBox.shrink();
    final rm = Map<String, dynamic>.from(ruta);
    final rk = _coerceInt(rm['RutaId'] ?? rm['rutaId']);
    final cursos = rk != null ? (_cursosPorRuta[rk] ?? []) : <dynamic>[];
    final titulo = rm['Nombre'] ?? rm['nombre'] ?? 'Ruta sin nombre';
    final desc = rm['Descripcion'] ?? rm['descripcion'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('ruta_$rk'),
            initiallyExpanded: index == 0,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding:
                const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route_rounded,
                  color: Colors.white, size: 22),
            ),
            title: Text(
              titulo.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: desc != null
                ? Text(
                    desc.toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  )
                : null,
            children: [
              if (cursos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay cursos en esta ruta',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                )
              else
                ...cursos.map((curso) {
                  if (curso is! Map) return const SizedBox.shrink();
                  return _buildCursoCard(
                    context,
                    Map<String, dynamic>.from(curso),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )
            : RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: _loadData,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _buildEncabezadoInicio(context)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTarjetaContinuar(context),
                              const SizedBox(height: 20),
                              _buildResumenMetricas(context),
                              const SizedBox(height: 28),
                              Text(
                                'Explorar rutas',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Despliega una ruta para ver sus cursos',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_rutas.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildEmptyState(context),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildRutaAcordeon(context, index),
                              childCount: _rutas.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRutaSection(
    BuildContext context,
    Map<String, dynamic> ruta,
    List<dynamic> cursos, {
    void Function(void Function() navegar)? alAbrirCurso,
    BuildContext? contextoNavegacion,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryLight,
                    AppTheme.accentColor,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ruta['Nombre'] ?? 'Ruta sin nombre',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (ruta['Descripcion'] != null)
                    Text(
                      ruta['Descripcion'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (cursos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 48,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay cursos disponibles',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...cursos.map((curso) {
            if (curso is! Map) return const SizedBox.shrink();
            return _buildCursoCard(
              context,
              Map<String, dynamic>.from(curso),
              alAbrir: alAbrirCurso,
              contextoNavegacion: contextoNavegacion,
            );
          }),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCursoCard(
    BuildContext context,
    Map<String, dynamic> curso, {
    void Function(void Function() navegar)? alAbrir,
    BuildContext? contextoNavegacion,
  }) {
    final leccionesCount = curso['Lecciones']?.length ?? 0;
    final isActive = curso['Activo'] == true;
    final navCtx = contextoNavegacion ?? context;

    void irALecciones() {
      final cursoId = curso['CursoId'] ?? curso['cursoId'];
      if (cursoId != null && cursoId > 0) {
        Navigator.of(navCtx).push(
          MaterialPageRoute(
            builder: (context) => LeccionesScreen(
              cursoId: cursoId is int
                  ? cursoId
                  : int.parse(cursoId.toString()),
              cursoNombre: curso['Nombre'] ?? 'Curso sin nombre',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: const Text(
              'Error: No se pudo obtener el ID del curso',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final ab = alAbrir;
            if (ab != null) {
              ab(irALecciones);
            } else {
              irALecciones();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icono del curso
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primaryColor
                        : Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isActive
                                    ? AppTheme.primaryColor
                                    : Colors.grey.shade400)
                                .withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Información del curso
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              curso['Nombre'] ?? 'Curso sin nombre',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Inactivo',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$leccionesCount ${leccionesCount == 1 ? 'lección' : 'lecciones'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          if (curso['Descripcion'] != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                curso['Descripcion'],
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeccionCard(
    BuildContext context,
    Map<String, dynamic> leccion, {
    void Function(void Function() navegar)? alAbrir,
    BuildContext? contextoNavegacion,
  }) {
    final leccionId = leccion['LeccionId'] ?? leccion['leccionId'];
    final titulo =
        leccion['Titulo'] ?? leccion['titulo'] ?? 'Lección sin nombre';
    final cursoNombre = leccion['cursoNombre'] ?? 'Curso sin nombre';
    final rutaNombre = leccion['rutaNombre'] ?? 'Ruta sin nombre';
    final cursoId = leccion['cursoId'];
    final navCtx = contextoNavegacion ?? context;

    void irADetalle() {
      if (leccionId != null && cursoId != null) {
        Navigator.of(navCtx).push(
          MaterialPageRoute(
            builder: (context) => LeccionDetalleScreen(
              leccionId: leccionId is int
                  ? leccionId
                  : int.parse(leccionId.toString()),
              leccionTitulo: titulo.toString(),
              cursoId: cursoId is int
                  ? cursoId
                  : int.parse(cursoId.toString()),
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final ab = alAbrir;
            if (ab != null) {
              ab(irADetalle);
            } else {
              irADetalle();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.article_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo.toString(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$rutaNombre > $cursoNombre',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppTheme.primaryColor.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryLight.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_outlined,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay rutas disponibles',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Las rutas de aprendizaje aparecerán aquí cuando estén disponibles',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, AppTheme.primaryColor.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryLight.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No se encontraron resultados',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Intenta buscar con otros términos',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BusquedaInicioSheet extends StatefulWidget {
  const _BusquedaInicioSheet({
    required this.contextoPrincipal,
    required this.filtrar,
    required this.rutas,
    required this.cursosPorRuta,
    required this.leccionesPorCurso,
    required this.buildLeccionCard,
    required this.buildCursoCard,
    required this.buildRutaSection,
    required this.buildNoResults,
  });

  final BuildContext contextoPrincipal;
  final _FiltroCatalogoFn filtrar;
  final List<dynamic> rutas;
  final Map<int, List<dynamic>> cursosPorRuta;
  final Map<int, List<dynamic>> leccionesPorCurso;
  final _LeccionCardBuilder buildLeccionCard;
  final _CursoCardBuilder buildCursoCard;
  final _RutaSectionBuilder buildRutaSection;
  final Widget Function(BuildContext) buildNoResults;

  @override
  State<_BusquedaInicioSheet> createState() => _BusquedaInicioSheetState();
}

class _BusquedaInicioSheetState extends State<_BusquedaInicioSheet> {
  late final TextEditingController _query;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _cerrarYLuego(void Function() navegar) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => navegar());
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.9;
    final pad = widget.filtrar(
      _query.text,
      widget.rutas,
      widget.cursosPorRuta,
      widget.leccionesPorCurso,
    );
    final principal = widget.contextoPrincipal;
    final hayTexto = _query.text.trim().isNotEmpty;
    final sinResultados = hayTexto &&
        pad.rutasFiltradas.isEmpty &&
        pad.leccionesFiltradas.isEmpty;

    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    'Buscar en el catálogo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rutas, cursos o lecciones…',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor),
                suffixIcon: _query.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (!hayTexto)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'Escribe para filtrar rutas, cursos y lecciones.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                if (sinResultados) widget.buildNoResults(context),
                if (hayTexto && pad.leccionesFiltradas.isNotEmpty) ...[
                  Text(
                    'Lecciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...pad.leccionesFiltradas.map((leccion) {
                    return widget.buildLeccionCard(
                      context,
                      Map<String, dynamic>.from(leccion as Map),
                      alAbrir: (nav) => _cerrarYLuego(nav),
                      contextoNavegacion: principal,
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                if (hayTexto && pad.rutasFiltradas.isNotEmpty) ...[
                  Text(
                    'Rutas y cursos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...pad.rutasFiltradas.map((ruta) {
                    if (ruta is! Map) return const SizedBox.shrink();
                    final rm = Map<String, dynamic>.from(ruta);
                    final rk = _coerceIntTop(rm['RutaId'] ?? rm['rutaId']);
                    final cursos = rk != null
                        ? (pad.cursosFiltradosPorRuta[rk] ?? [])
                        : <dynamic>[];
                    return widget.buildRutaSection(
                      context,
                      rm,
                      cursos,
                      alAbrirCurso: (nav) => _cerrarYLuego(nav),
                      contextoNavegacion: principal,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
