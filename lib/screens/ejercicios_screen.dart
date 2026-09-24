import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/practicas_service.dart';
import '../services/progreso_service.dart';
import 'practica_detalle_screen.dart';

class EjerciciosScreen extends StatefulWidget {
  const EjerciciosScreen({super.key});

  @override
  State<EjerciciosScreen> createState() => _EjerciciosScreenState();
}

class _EjerciciosScreenState extends State<EjerciciosScreen> {
  final _practicasService = PracticasService();
  final _progresoService = ProgresoService();

  bool _isLoading = true;
  List<dynamic> _practicas = [];
  List<dynamic> _practicasFiltradas = [];
  Set<int> _practicasCompletadasIds = {};
  String _filtroTipo = 'Todos';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _aplicarFiltros();
  }

  int _completadasEnLista(List<dynamic> lista) {
    var n = 0;
    for (final p in lista) {
      if (_isPracticaCompletada(p)) n++;
    }
    return n;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final practicasResult = await _practicasService.getAllPracticas();

      if (practicasResult['success'] == true) {
        final practicas = practicasResult['practicas'] as List;

        final practicasCompletadasResult = await _progresoService.obtenerPracticasCompletadas();
        Set<int> completadasIds = {};

        if (practicasCompletadasResult['success'] == true) {
          final practicaIds = practicasCompletadasResult['practicaIds'] as List?;
          if (practicaIds != null) {
            completadasIds = practicaIds.map((e) {
              if (e is int) return e;
              return int.tryParse(e.toString()) ?? 0;
            }).where((id) => id > 0).toSet();
          }
        }

        if (!mounted) return;
        setState(() {
          _practicas = practicas;
          _practicasCompletadasIds = completadasIds;
          _isLoading = false;
        });
        _aplicarFiltros();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(practicasResult['message']?.toString() ?? 'Error al cargar ejercicios'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ejercicios: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _aplicarFiltros() {
    List<dynamic> filtradas = List.from(_practicas);

    if (_filtroTipo != 'Todos') {
      filtradas = filtradas.where((p) {
        final tipo = p['tipoEjercicio'] ?? p['TipoEjercicio'] ?? '';
        return tipo.toString() == _filtroTipo;
      }).toList();
    }

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtradas = filtradas.where((p) {
        final titulo = (p['titulo'] ?? p['Titulo'] ?? '').toString().toLowerCase();
        final descripcion = (p['descripcion'] ?? p['Descripcion'] ?? '').toString().toLowerCase();
        final leccionNombre =
            (p['leccion']?['titulo'] ?? p['Leccion']?['Titulo'] ?? '').toString().toLowerCase();
        final cursoNombre = (p['leccion']?['curso']?['nombre'] ?? p['Leccion']?['Curso']?['Nombre'] ?? '')
            .toString()
            .toLowerCase();

        return titulo.contains(query) ||
            descripcion.contains(query) ||
            leccionNombre.contains(query) ||
            cursoNombre.contains(query);
      }).toList();
    }

    setState(() {
      _practicasFiltradas = filtradas;
    });
  }

  String _getTipoEjercicioNombre(String tipo) {
    switch (tipo) {
      case 'MultipleChoice':
        return 'Opción múltiple';
      case 'CompletarCodigo':
        return 'Completar código';
      case 'EscribirCodigo':
        return 'Escribir código';
      default:
        return tipo;
    }
  }

  Color _getTipoEjercicioColor(String tipo) {
    switch (tipo) {
      case 'MultipleChoice':
        return const Color(0xFF2563EB);
      case 'CompletarCodigo':
        return const Color(0xFF7C3AED);
      case 'EscribirCodigo':
        return const Color(0xFFD97706);
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getTipoEjercicioIcon(String tipo) {
    switch (tipo) {
      case 'MultipleChoice':
        return Icons.quiz_rounded;
      case 'CompletarCodigo':
        return Icons.data_object_rounded;
      case 'EscribirCodigo':
        return Icons.keyboard_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  bool _isPracticaCompletada(dynamic practica) {
    final id = practica['practicaId'] ?? practica['PracticaId'];
    final asInt = id is int ? id : int.tryParse(id?.toString() ?? '');
    return asInt != null && _practicasCompletadasIds.contains(asInt);
  }

  int? _practicaIdAsInt(dynamic practica) {
    final id = practica['practicaId'] ?? practica['PracticaId'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navPad = 72.0 + bottomInset;
    final total = _practicas.length;
    final hechasTotal = _completadasEnLista(_practicas);

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
                            _buildEjerciciosHeroHeader(context),
                            const SizedBox(height: 16),
                            _buildResumenRow(context, total, hechasTotal),
                            const SizedBox(height: 20),
                            Text(
                              'Tipo de ejercicio',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCategoryChip('Todos'),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip('MultipleChoice'),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip('CompletarCodigo'),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip('EscribirCodigo'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    if (_practicasFiltradas.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == _practicasFiltradas.length - 1 ? navPad : 12,
                                ),
                                child: _buildExerciseCard(context, _practicasFiltradas[index]),
                              );
                            },
                            childCount: _practicasFiltradas.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEjerciciosHeroHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryDark,
            const Color(0xFF4C1D95),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -24,
            child: Icon(
              Icons.auto_awesome,
              size: 120,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            left: -16,
            bottom: 100,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 390;

                    final refreshButton = Tooltip(
                      message:
                          'Vuelve a cargar ejercicios y tu progreso desde el servidor. También puedes deslizar hacia abajo en la pantalla.',
                      child: FilledButton.tonalIcon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.sync_rounded, size: 20),
                        label: const Text('Actualizar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.psychology_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Ejercicios interactivos',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                        height: 1.2,
                                      ),
                                ),
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 8),
                              refreshButton,
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Repasa cada lección con retos de opción múltiple, completar código y escritura. '
                          'Desliza hacia abajo en la lista o pulsa Actualizar para sincronizar.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.96),
                                height: 1.5,
                              ),
                        ),
                        if (isCompact) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: refreshButton,
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.manage_search_rounded, color: AppTheme.primaryColor, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Buscar en la lista',
                            style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por nombre del ejercicio, lección o curso.',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildSearchTextField(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenRow(
    BuildContext context,
    int total,
    int hechasTotal,
  ) {
    return Row(
      children: [
        Expanded(
          child: _SummaryPill(
            icon: Icons.assignment_outlined,
            label: 'En el catálogo',
            value: '$total',
            subtitle: total == 1 ? 'ejercicio' : 'ejercicios',
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(
            icon: Icons.check_circle_outline_rounded,
            label: 'Completados',
            value: '$hechasTotal',
            subtitle: 'de $total',
            color: AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTextField() {
    return Material(
      color: AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: ListenableBuilder(
        listenable: _searchController,
        builder: (context, _) {
          return TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Texto a buscar',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              hintText: 'Ej.: condicionales, bucles, Fundamentos de C#…',
              hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Borrar búsqueda',
                      icon: Icon(Icons.clear_rounded, color: Colors.grey.shade600),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hayFiltro = _filtroTipo != 'Todos' || _searchController.text.trim().isNotEmpty;
    final sinDatos = _practicas.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            sinDatos ? Icons.inbox_outlined : Icons.search_off_rounded,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            sinDatos
                ? 'No hay ejercicios disponibles'
                : hayFiltro
                    ? 'Nada coincide con tu búsqueda'
                    : 'No hay ejercicios para mostrar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            sinDatos
                ? 'Vuelve más tarde o revisa tu conexión.'
                : hayFiltro
                    ? 'Prueba otras palabras o quita el filtro de tipo.'
                    : '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String tipo) {
    final isSelected = _filtroTipo == tipo;
    final label = tipo == 'Todos' ? 'Todos' : _getTipoEjercicioNombre(tipo);
    final color = tipo == 'Todos' ? AppTheme.primaryColor : _getTipoEjercicioColor(tipo);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? Icons.check_rounded : _getTipoEjercicioIcon(tipo),
            size: 16,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filtroTipo = tipo;
        });
        _aplicarFiltros();
      },
      selectedColor: color.withValues(alpha: 0.14),
      checkmarkColor: color,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: isSelected ? color : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _buildExerciseCard(BuildContext context, dynamic practica) {
    final practicaId = _practicaIdAsInt(practica);
    final titulo = practica['titulo'] ?? practica['Titulo'] ?? 'Ejercicio sin título';
    final descripcion = practica['descripcion'] ?? practica['Descripcion'] ?? '';
    final tipo = (practica['tipoEjercicio'] ?? practica['TipoEjercicio'] ?? '').toString();
    final leccion = practica['leccion'] ?? practica['Leccion'];
    final curso = leccion?['curso'] ?? leccion?['Curso'];
    final ruta = curso?['ruta'] ?? curso?['Ruta'];

    final leccionNombre = leccion?['titulo'] ?? leccion?['Titulo'] ?? '';
    final cursoNombre = curso?['nombre'] ?? curso?['Nombre'] ?? '';
    final rutaNombre = ruta?['nombre'] ?? ruta?['Nombre'] ?? '';

    final isCompletada = _isPracticaCompletada(practica);
    final tipoColor = _getTipoEjercicioColor(tipo);
    final tipoIcon = _getTipoEjercicioIcon(tipo);

    if (practicaId == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context)
              .push(
            MaterialPageRoute<void>(
              builder: (context) => PracticaDetalleScreen(
                practicaId: practicaId,
                practicaTitulo: titulo is String ? titulo : titulo.toString(),
              ),
            ),
          )
              .then((_) => _loadData());
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompletada
                  ? AppTheme.successColor.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.06),
              width: isCompletada ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    color: isCompletada ? AppTheme.successColor : tipoColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tipoColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(tipoIcon, color: tipoColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      titulo is String ? titulo : titulo.toString(),
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _TipoBadge(
                                          label: _getTipoEjercicioNombre(tipo),
                                          color: tipoColor,
                                          icon: tipoIcon,
                                        ),
                                        if (isCompletada) const _CompletadaBadge(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                            ],
                          ),
                          if (descripcion.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              descripcion.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.45,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (rutaNombre.toString().isNotEmpty ||
                              cursoNombre.toString().isNotEmpty ||
                              leccionNombre.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              [
                                if (rutaNombre.toString().isNotEmpty) rutaNombre.toString(),
                                if (cursoNombre.toString().isNotEmpty) cursoNombre.toString(),
                                if (leccionNombre.toString().isNotEmpty) leccionNombre.toString(),
                              ].join(' · '),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
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
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipoBadge extends StatelessWidget {
  const _TipoBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
}

class _CompletadaBadge extends StatelessWidget {
  const _CompletadaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: AppTheme.successColor),
          const SizedBox(width: 5),
          Text(
            'Hecha',
            style: TextStyle(
              color: AppTheme.successColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
