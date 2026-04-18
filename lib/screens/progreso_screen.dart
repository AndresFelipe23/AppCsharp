import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/progreso_service.dart';
import 'lecciones_screen.dart';

class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  final _progresoService = ProgresoService();
  Map<String, dynamic>? _estadisticas;
  Map<String, dynamic>? _progresoCompleto;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  int _intFromStats(String camel, [String? pascal]) {
    final m = _estadisticas;
    if (m == null) return 0;
    final v = m[camel] ?? (pascal != null ? m[pascal] : null);
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  double _fraccionHastaSiguienteNivel() {
    final pts = _intFromStats('puntosTotales', 'PuntosTotales');
    return (pts % 100) / 100.0;
  }

  int _puntosParaSiguienteTramo() {
    final pts = _intFromStats('puntosTotales', 'PuntosTotales');
    return 100 - (pts % 100);
  }

  List<dynamic> _listaProgreso(String camel, String pascal) {
    final m = _progresoCompleto;
    if (m == null) return const [];
    final raw = m[camel] ?? m[pascal];
    if (raw is List) return raw;
    return const [];
  }

  int? _coerceInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  void _abrirLeccionesCurso(BuildContext context, int cursoId, String cursoNombre) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LeccionesScreen(
          cursoId: cursoId,
          cursoNombre: cursoNombre,
        ),
      ),
    );
  }

  void _mostrarCursosDeRuta(BuildContext context, int rutaId, String rutaNombre) {
    final todos = _listaProgreso('progresoCursos', 'ProgresoCursos');
    final filtrados = todos.where((c) => _coerceInt(c['rutaId'] ?? c['RutaId']) == rutaId).toList();

    if (filtrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cursos listados para esta ruta.')),
      );
      return;
    }

    final sheetH = MediaQuery.sizeOf(context).height * 0.52;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Cursos · $rutaNombre',
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  'Toca un curso para abrir sus lecciones',
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtrados.length,
                    separatorBuilder: (context, _) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (ctx, i) {
                      final c = filtrados[i];
                      final nom = (c['nombre'] ?? c['Nombre'] ?? 'Curso').toString();
                      final pctRaw = c['porcentajeCompletado'] ?? c['PorcentajeCompletado'] ?? 0;
                      final pct = pctRaw is double
                          ? pctRaw
                          : (pctRaw is int ? pctRaw.toDouble() : double.tryParse(pctRaw.toString()) ?? 0);
                      final cid = _coerceInt(c['cursoId'] ?? c['CursoId']);
                      return ListTile(
                        title: Text(nom, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${pct.toStringAsFixed(0)}% del curso'),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.primaryColor),
                        onTap: cid == null
                            ? null
                            : () {
                                Navigator.pop(sheetCtx);
                                _abrirLeccionesCurso(context, cid, nom);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final results = await Future.wait([
      _progresoService.obtenerEstadisticas(),
      _progresoService.obtenerProgresoCompleto(),
    ]);

    final estadisticasResult = results[0];
    final progresoCompletoResult = results[1];

    Map<String, dynamic>? stats;
    if (estadisticasResult['success'] == true && estadisticasResult['estadisticas'] != null) {
      stats = Map<String, dynamic>.from(
        estadisticasResult['estadisticas'] as Map,
      );
    }

    Map<String, dynamic>? progresoMap;
    if (progresoCompletoResult['success'] == true) {
      final raw = progresoCompletoResult['progreso'] ?? progresoCompletoResult['progresoCompleto'];
      if (raw is Map) {
        progresoMap = Map<String, dynamic>.from(raw);
      }
    }

    if (stats == null && progresoMap != null) {
      final nested = progresoMap['estadisticas'] ?? progresoMap['Estadisticas'];
      if (nested is Map) {
        stats = Map<String, dynamic>.from(nested);
      }
    }

    if (!mounted) return;
    setState(() {
      _estadisticas = stats;
      _progresoCompleto = progresoMap;
      _isLoading = false;
    });

    if (mounted &&
        estadisticasResult['success'] != true &&
        progresoCompletoResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estadisticasResult['message']?.toString() ??
                progresoCompletoResult['message']?.toString() ??
                'Error al cargar el progreso',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navPad = 72.0 + bottomInset;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primaryColor,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, navPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPageHeader(context),
                            const SizedBox(height: 20),
                            _buildNivelCard(context),
                            const SizedBox(height: 20),
                            _buildStatsGrid(context),
                            const SizedBox(height: 28),
                            ..._buildRutasSection(context),
                            ..._buildCursosSection(context),
                            if (_progresoCompleto != null &&
                                _listaProgreso('progresoRutas', 'ProgresoRutas').isEmpty &&
                                _listaProgreso('progresoCursos', 'ProgresoCursos').isEmpty)
                              _buildEmptyHint(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu progreso',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resumen de tu actividad y avance por curso',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildNivelCard(BuildContext context) {
    final nivel = _intFromStats('nivel', 'Nivel');
    final puntos = _intFromStats('puntosTotales', 'PuntosTotales');
    final frac = _fraccionHastaSiguienteNivel();
    final ptsFaltan = _puntosParaSiguienteTramo();

    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryDark,
              const Color(0xFF4C1D95),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: frac.clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      color: AppTheme.accentColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$nivel',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                      ),
                      Text(
                        'Nivel',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sigue sumando puntos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    puntos == 0
                        ? 'Completa lecciones y prácticas para ganar puntos y subir de nivel.'
                        : 'Te faltan $ptsFaltan pts para el siguiente tramo (cada 100 pts subes un nivel).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.amber.shade200, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '$puntos puntos totales',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final items = [
      (
        'Lecciones',
        '${_intFromStats('leccionesCompletadas', 'LeccionesCompletadas')}',
        Icons.menu_book_rounded,
        AppTheme.primaryColor,
      ),
      (
        'Prácticas',
        '${_intFromStats('practicasCompletadas', 'PracticasCompletadas')}',
        Icons.fact_check_rounded,
        AppTheme.successColor,
      ),
      (
        'Retos',
        '${_intFromStats('retosCompletados', 'RetosCompletados')}',
        Icons.flag_rounded,
        const Color(0xFFFF6B35),
      ),
      (
        'Puntos',
        '${_intFromStats('puntosTotales', 'PuntosTotales')}',
        Icons.bolt_rounded,
        const Color(0xFFFFC107),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: items
          .map(
            (e) => _StatTile(
              label: e.$1,
              value: e.$2,
              icon: e.$3,
              accent: e.$4,
            ),
          )
          .toList(),
    );
  }

  List<Widget> _buildRutasSection(BuildContext context) {
    final rutas = _listaProgreso('progresoRutas', 'ProgresoRutas');
    if (rutas.isEmpty) return [];

    return [
      _SectionTitle(icon: Icons.route_rounded, title: 'Rutas de aprendizaje'),
      const SizedBox(height: 12),
      ...rutas.map((ruta) => _buildRutaProgressCard(context, ruta)),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildCursosSection(BuildContext context) {
    final cursos = _listaProgreso('progresoCursos', 'ProgresoCursos');
    if (cursos.isEmpty) return [];

    return [
      _SectionTitle(icon: Icons.school_rounded, title: 'Cursos'),
      const SizedBox(height: 12),
      ...cursos.map((curso) => _buildCursoProgressCard(context, curso)),
    ];
  }

  Widget _buildEmptyHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.insights_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No hay rutas ni cursos activos en el catálogo, o aún no se pudo cargar el detalle.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRutaProgressCard(BuildContext context, dynamic ruta) {
    final rutaId = _coerceInt(ruta['rutaId'] ?? ruta['RutaId']);
    final nombre = ruta['nombre'] ?? ruta['Nombre'] ?? 'Ruta sin nombre';
    final porcentajeRaw = ruta['porcentajeCompletado'] ?? ruta['PorcentajeCompletado'] ?? 0.0;
    final porcentaje = porcentajeRaw is double
        ? porcentajeRaw
        : (porcentajeRaw is int ? porcentajeRaw.toDouble() : 0.0);
    final cursosCompletados = ruta['cursosCompletados'] ?? ruta['CursosCompletados'] ?? 0;
    final totalCursos = ruta['totalCursos'] ?? ruta['TotalCursos'] ?? 0;
    final hecho = porcentaje >= 99.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: rutaId == null
              ? null
              : () => _mostrarCursosDeRuta(context, rutaId, nombre.toString()),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 52,
                        decoration: BoxDecoration(
                          color: hecho ? AppTheme.successColor : AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.toString(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$cursosCompletados de $totalCursos cursos',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            if (rutaId != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Toca para ver los cursos de esta ruta',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (hecho ? AppTheme.successColor : AppTheme.primaryColor).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${porcentaje.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: hecho ? AppTheme.successColor : AppTheme.primaryColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (porcentaje / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppTheme.backgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hecho ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCursoProgressCard(BuildContext context, dynamic curso) {
    final nombre = curso['nombre'] ?? curso['Nombre'] ?? 'Curso sin nombre';
    final rutaNombre = curso['rutaNombre'] ?? curso['RutaNombre'] ?? '';
    final porcentajeRaw = curso['porcentajeCompletado'] ?? curso['PorcentajeCompletado'] ?? 0.0;
    final porcentaje = porcentajeRaw is double
        ? porcentajeRaw
        : (porcentajeRaw is int ? porcentajeRaw.toDouble() : 0.0);
    final leccionesCompletadas = curso['leccionesCompletadas'] ?? curso['LeccionesCompletadas'] ?? 0;
    final totalLecciones = curso['totalLecciones'] ?? curso['TotalLecciones'] ?? 0;
    final practicasCompletadas = curso['practicasCompletadas'] ?? curso['PracticasCompletadas'] ?? 0;
    final totalPracticas = curso['totalPracticas'] ?? curso['TotalPracticas'] ?? 0;
    final hecho = porcentaje >= 99.5;
    final cursoId = _coerceInt(curso['cursoId'] ?? curso['CursoId']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: cursoId == null
              ? null
              : () => _abrirLeccionesCurso(context, cursoId, nombre.toString()),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: (hecho ? AppTheme.successColor : AppTheme.primaryColor).withValues(alpha: 0.15),
                        child: Icon(
                          hecho ? Icons.verified_rounded : Icons.menu_book_rounded,
                          color: hecho ? AppTheme.successColor : AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre.toString(),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (rutaNombre.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                rutaNombre.toString(),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (cursoId != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Toca para abrir lecciones',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${porcentaje.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: hecho ? AppTheme.successColor : AppTheme.primaryColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (porcentaje / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppTheme.backgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        hecho ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _MiniChip(
                        icon: Icons.article_outlined,
                        text: '$leccionesCompletadas/$totalLecciones lecciones',
                      ),
                      if (totalPracticas > 0)
                        _MiniChip(
                          icon: Icons.quiz_outlined,
                          text: '$practicasCompletadas/$totalPracticas prácticas',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}
