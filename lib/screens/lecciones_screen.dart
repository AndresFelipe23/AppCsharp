import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/lecciones_service.dart';
import '../services/progreso_service.dart';
import 'leccion_detalle_screen.dart';

class LeccionesScreen extends StatefulWidget {
  final int cursoId;
  final String cursoNombre;

  const LeccionesScreen({
    super.key,
    required this.cursoId,
    required this.cursoNombre,
  });

  @override
  State<LeccionesScreen> createState() => _LeccionesScreenState();
}

class _LeccionesScreenState extends State<LeccionesScreen>
    with SingleTickerProviderStateMixin {
  final _leccionesService = LeccionesService();
  final _progresoService = ProgresoService();
  List<dynamic> _lecciones = [];
  Set<int> _leccionesCompletadas = {};
  /// Conteos del backend para este curso (`GET /progreso/completo` → progresoCursos).
  Map<String, int>? _statsCurso;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int _ordenLeccion(Map<String, dynamic> m) {
    return _coerceInt(m['Orden'] ?? m['orden']) ?? 0;
  }

  void _ordenarLeccionesInPlace() {
    _lecciones.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      return _ordenLeccion(Map<String, dynamic>.from(a))
          .compareTo(_ordenLeccion(Map<String, dynamic>.from(b)));
    });
  }

  int? _idLeccion(Map<String, dynamic> m) {
    return _coerceInt(
      m['LeccionId'] ??
          m['leccionId'] ??
          m['ID'] ??
          m['id'] ??
          m['Id'],
    );
  }

  int get _completadasEnCurso {
    var n = 0;
    for (final l in _lecciones) {
      if (l is! Map) continue;
      final id = _idLeccion(Map<String, dynamic>.from(l));
      if (id != null && _leccionesCompletadas.contains(id)) n++;
    }
    return n;
  }

  int get _totalLecciones => _lecciones.length;

  /// Totales mostrados en la barra: prioriza datos de `progreso/completo` del curso.
  int get _totalBarra {
    final st = _statsCurso;
    final tl = st?['tl'];
    if (tl != null && tl > 0) return tl;
    return _totalLecciones;
  }

  int get _hechasBarra {
    final st = _statsCurso;
    final tl = st?['tl'];
    final lc = st?['lc'];
    if (tl != null && tl > 0 && lc != null) {
      return lc.clamp(0, tl);
    }
    return _completadasEnCurso;
  }

  double get _fraccionBarra {
    final t = _totalBarra;
    if (t <= 0) return 0;
    return (_hechasBarra / t).clamp(0.0, 1.0);
  }

  bool _cursoCompletoEnBackend() {
    final st = _statsCurso;
    if (st == null) return false;
    final lc = st['lc'] ?? 0;
    final tl = st['tl'] ?? 0;
    return tl > 0 && lc >= tl && _lecciones.length == tl;
  }

  bool _leccionCompletadaUi(Map<String, dynamic> leccion, int? leccionId) {
    if (leccionId != null && _leccionesCompletadas.contains(leccionId)) {
      return true;
    }
    return _cursoCompletoEnBackend();
  }

  Map<String, int>? _statsFromProgresoCompleto(dynamic progresoRoot) {
    if (progresoRoot is! Map) return null;
    final root = Map<String, dynamic>.from(progresoRoot);
    final list = root['progresoCursos'] ?? root['ProgresoCursos'];
    if (list is! List) return null;
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cid = _coerceInt(m['cursoId'] ?? m['CursoId']);
      if (cid != null && cid == widget.cursoId) {
        final lc =
            _coerceInt(m['leccionesCompletadas'] ?? m['LeccionesCompletadas']) ??
                0;
        final tl =
            _coerceInt(m['totalLecciones'] ?? m['TotalLecciones']) ?? 0;
        if (tl > 0) {
          return {'lc': lc, 'tl': tl};
        }
        return null;
      }
    }
    return null;
  }

  /// IDs de lecciones completadas en este curso según `GET /progreso/completo` → `progresoCursos`.
  Set<int> _idsLeccionesCompletadasDelCursoEnProgreso(
    dynamic progresoRoot,
    int cursoId,
  ) {
    if (progresoRoot is! Map) return {};
    final root = Map<String, dynamic>.from(progresoRoot);
    final list = root['progresoCursos'] ?? root['ProgresoCursos'];
    if (list is! List) return {};
    for (final raw in list) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final cid = _coerceInt(m['cursoId'] ?? m['CursoId']);
      if (cid != null && cid == cursoId) {
        final idsRaw =
            m['leccionesCompletadasIds'] ?? m['LeccionesCompletadasIds'];
        if (idsRaw is! List) return {};
        final out = <int>{};
        for (final e in idsRaw) {
          if (e is int) {
            if (e > 0) out.add(e);
          } else if (e is num) {
            final v = e.toInt();
            if (v > 0) out.add(v);
          } else {
            final v = int.tryParse(e.toString());
            if (v != null && v > 0) out.add(v);
          }
        }
        return out;
      }
    }
    return {};
  }

  Future<void> _loadData({bool mostrarCarga = true}) async {
    if (mostrarCarga) {
      setState(() {
        _isLoading = true;
      });
    }

    if (widget.cursoId <= 0) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: ID de curso inválido'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      _animationController.forward();
      return;
    }

    final results = await Future.wait([
      _leccionesService.getLeccionesByCurso(widget.cursoId),
      _progresoService.obtenerLeccionesCompletadas(),
      _progresoService.obtenerProgresoCompleto(),
      _progresoService.obtenerLeccionesCompletadasPorCurso(widget.cursoId),
    ]);

    final leccionesResult = results[0];
    final progresoResult = results[1];
    final progresoCompletoResult = results[2];
    final completadasCursoResult = results[3];

    if (leccionesResult['success'] == true) {
      final lecciones = List<dynamic>.from(leccionesResult['lecciones'] as List);

      var mergedCompletadas = <int>{};
      if (progresoResult['success'] == true) {
        final rawIds = progresoResult['leccionesIds'];
        if (rawIds is List) {
          mergedCompletadas = rawIds
              .map((id) {
                if (id is int) return id;
                if (id is num) return id.toInt();
                return int.tryParse(id.toString()) ?? 0;
              })
              .where((id) => id > 0)
              .toSet();
        }
      }
      if (progresoCompletoResult['success'] == true &&
          progresoCompletoResult['progreso'] != null) {
        mergedCompletadas = {
          ...mergedCompletadas,
          ..._idsLeccionesCompletadasDelCursoEnProgreso(
            progresoCompletoResult['progreso'],
            widget.cursoId,
          ),
        };
      }
      if (completadasCursoResult['success'] == true) {
        final rawCurso = completadasCursoResult['leccionesIds'];
        if (rawCurso is List) {
          mergedCompletadas = {
            ...mergedCompletadas,
            ...rawCurso
                .map((id) {
                  if (id is int) return id;
                  if (id is num) return id.toInt();
                  return int.tryParse(id.toString()) ?? 0;
                })
                .where((id) => id > 0),
          };
        }
      }

      Map<String, int>? stats;
      if (progresoCompletoResult['success'] == true &&
          progresoCompletoResult['progreso'] != null) {
        stats = _statsFromProgresoCompleto(progresoCompletoResult['progreso']);
      } else {
        stats = null;
      }

      setState(() {
        _lecciones = lecciones;
        _ordenarLeccionesInPlace();
        _statsCurso = stats;
        _leccionesCompletadas = mergedCompletadas;
        _isLoading = false;
      });
    } else {
      final errorMessage =
          leccionesResult['message'] ?? 'Error al cargar las lecciones';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _statsCurso = null;
        _isLoading = false;
      });
    }
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final hechas = _hechasBarra;
    final total = _totalBarra;
    final progreso = _fraccionBarra;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () => _loadData(mostrarCarga: false),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                      pinned: true,
                      elevation: 0,
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: Text(
                        widget.cursoNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: _buildTarjetaProgreso(
                            context,
                            hechas: hechas,
                            total: total,
                            fraccion: progreso,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (_lecciones.isEmpty) {
                                return index == 0
                                    ? _buildEmptyState(context)
                                    : null;
                              }
                              final leccion = _lecciones[index];
                              if (leccion is! Map) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _lecciones.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _buildLeccionPaso(
                                  context,
                                  Map<String, dynamic>.from(leccion),
                                  index,
                                  index == _lecciones.length - 1,
                                ),
                              );
                            },
                            childCount:
                                _lecciones.isEmpty ? 1 : _lecciones.length,
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

  Widget _buildTarjetaProgreso(
    BuildContext context, {
    required int hechas,
    required int total,
    required double fraccion,
  }) {
    final pct = (fraccion * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$hechas de $total lecciones completadas',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              Text(
                '$pct%',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pct >= 100
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total > 0 ? fraccion.clamp(0.0, 1.0) : 0,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct >= 100 ? AppTheme.successColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeccionPaso(
    BuildContext context,
    Map<String, dynamic> leccion,
    int index,
    bool isUltima,
  ) {
    final isActive = leccion['Activo'] == true || leccion['activo'] == true;
    final practicasCount = leccion['Practicas']?.length ?? 0;
    final leccionId = _idLeccion(leccion);
    final isCompletada = _leccionCompletadaUi(leccion, leccionId);
    final titulo =
        leccion['Titulo'] ?? leccion['titulo'] ?? 'Lección sin título';
    final descCorta =
        leccion['DescripcionCorta'] ?? leccion['descripcionCorta'];

    final Color acento;
    if (isCompletada) {
      acento = AppTheme.successColor;
    } else if (isActive) {
      acento = AppTheme.primaryColor;
    } else {
      acento = Colors.grey.shade400;
    }

    final Color fondoIndicador;
    if (isCompletada) {
      fondoIndicador = AppTheme.successColor;
    } else if (isActive) {
      fondoIndicador = AppTheme.primaryColor;
    } else {
      fondoIndicador = Colors.grey.shade500;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (leccionId != null && leccionId > 0) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LeccionDetalleScreen(
                  leccionId: leccionId,
                  leccionTitulo: titulo.toString(),
                  cursoId: widget.cursoId,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: isCompletada
                ? AppTheme.successColor.withOpacity(0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isCompletada
                  ? AppTheme.successColor.withOpacity(0.45)
                  : Colors.grey.shade200,
              width: isCompletada ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: fondoIndicador,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompletada
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      if (!isUltima)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                titulo.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                      color: isCompletada
                                          ? AppTheme.textPrimary
                                              .withOpacity(0.75)
                                          : AppTheme.textPrimary,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                              size: 26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isCompletada)
                              _chipEstado(
                                context,
                                label: 'Completada',
                                color: AppTheme.successColor,
                                icon: Icons.check_circle_outline_rounded,
                              )
                            else if (!isActive)
                              _chipEstado(
                                context,
                                label: 'Inactiva',
                                color: Colors.grey.shade600,
                                icon: Icons.lock_outline_rounded,
                              ),
                            if (practicasCount > 0)
                              _chipEstado(
                                context,
                                label:
                                    '$practicasCount ${practicasCount == 1 ? 'práctica' : 'prácticas'}',
                                color: AppTheme.primaryColor,
                                icon: Icons.quiz_outlined,
                              ),
                          ],
                        ),
                        if (descCorta != null &&
                            descCorta.toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            descCorta.toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.35,
                                ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Paso ${index + 1} de ${_lecciones.length}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.textSecondary.withOpacity(0.85),
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: acento,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(18),
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

  Widget _chipEstado(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 36,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No hay lecciones disponibles',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Las lecciones aparecerán aquí cuando estén publicadas en este curso.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
