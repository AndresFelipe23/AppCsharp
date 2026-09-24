import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/practicas_service.dart';
import '../services/progreso_service.dart';
import '../widgets/csharp_syntax_highlighter.dart';

class PracticaDetalleScreen extends StatefulWidget {
  final int practicaId;
  final String practicaTitulo;

  const PracticaDetalleScreen({
    super.key,
    required this.practicaId,
    required this.practicaTitulo,
  });

  @override
  State<PracticaDetalleScreen> createState() => _PracticaDetalleScreenState();
}

class _PracticaDetalleScreenState extends State<PracticaDetalleScreen> {
  final _practicasService = PracticasService();
  final _progresoService = ProgresoService();

  bool _isLoading = true;
  bool _isSubmitting = false;

  Map<String, dynamic>? _practica;
  Map<String, dynamic>? _progreso;

  // Estado UI por tipo
  int? _selectedOpcionId;

  // CompletarCodigo (estilo Duolingo)
  List<Map<String, dynamic>> _allBloques = []; // Todos los bloques (correctos + distractores)
  List<Map<String, dynamic>> _bloquesDisponibles = []; // Bloques disponibles para seleccionar
  List<Map<String, dynamic>> _bloquesColocados = []; // Bloques colocados en orden
  String _codigoBase = ''; // Código base con espacios para los bloques

  // EscribirCodigo
  final _codigoController = TextEditingController();

  // Estado para mostrar/ocultar pistas
  bool _mostrarPista = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  bool get _estaCompletada {
    return _progreso?['Completada'] == true || _progreso?['completada'] == true;
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _practicasService.getPractica(widget.practicaId),
      _progresoService.obtenerProgresoPractica(widget.practicaId),
    ]);

    final practicaResult = results[0];
    final progresoResult = results[1];

    if (practicaResult['success'] == true && practicaResult['practica'] != null) {
      _practica = (practicaResult['practica'] as Map).cast<String, dynamic>();
    }

    if (progresoResult['success'] == true && progresoResult['progreso'] != null) {
      _progreso = (progresoResult['progreso'] as Map).cast<String, dynamic>();
    } else {
      _progreso = null;
    }

    _hydrateFromPreviousAnswer();

    setState(() => _isLoading = false);
  }

  void _hydrateFromPreviousAnswer() {
    if (_practica == null) return;

    final tipo = _practica?['TipoEjercicio'] ?? _practica?['tipoEjercicio'];

    // Preparar bloques para CompletarCodigo (estilo Duolingo)
    if (tipo == 'CompletarCodigo') {
      final bloques = (_practica?['Bloques'] ?? _practica?['bloques']) as List<dynamic>? ?? [];
      _allBloques = bloques.map((b) => (b as Map).cast<String, dynamic>()).toList();
      
      // Obtener código base del primer bloque (todos deberían tener el mismo)
      if (_allBloques.isNotEmpty) {
        _codigoBase = (_allBloques[0]['CodigoBase'] ?? _allBloques[0]['codigoBase'] ?? '').toString();
      }
      
      // Inicializar: todos los bloques disponibles, ninguno colocado
      _bloquesDisponibles = List.from(_allBloques);
      _bloquesDisponibles.shuffle(Random());
      _bloquesColocados = [];
    }

    // Si hay respuesta previa, precargarla
    final respuestaRaw = _progreso?['RespuestaUsuario'] ?? _progreso?['respuestaUsuario'];
    if (respuestaRaw == null || respuestaRaw.toString().trim().isEmpty) return;

    try {
      final parsed = jsonDecode(respuestaRaw.toString()) as Map<String, dynamic>;

      if (tipo == 'MultipleChoice') {
        final mc = parsed['MultipleChoice'] as Map<String, dynamic>?;
        final opcionId = mc?['OpcionId'];
        if (opcionId != null) {
          _selectedOpcionId = (opcionId is int) ? opcionId : int.tryParse(opcionId.toString());
        }
      }

      if (tipo == 'CompletarCodigo') {
        final cc = parsed['CompletarCodigo'] as Map<String, dynamic>?;
        final orden = cc?['BloquesOrden'];
        if (orden is List) {
          final bloqueIds = orden.map((e) => e is int ? e : int.parse(e.toString())).toList();
          // Restaurar orden previo
          _bloquesColocados = bloqueIds.map((id) {
            return _allBloques.firstWhere((b) => (b['BloqueId'] ?? b['bloqueId']) == id);
          }).toList();
          // Remover los colocados de los disponibles
          _bloquesDisponibles = _allBloques.where((b) {
            final bid = (b['BloqueId'] ?? b['bloqueId']) as int;
            return !bloqueIds.contains(bid);
          }).toList();
          _bloquesDisponibles.shuffle(Random());
        }
      }

      if (tipo == 'EscribirCodigo') {
        final ec = parsed['EscribirCodigo'] as Map<String, dynamic>?;
        final codigo = ec?['CodigoUsuario'];
        if (codigo != null) {
          _codigoController.text = codigo.toString();
        }
      }
    } catch (_) {
      // Si falla el parse, no romper la UI
    }
  }

  Future<void> _submit() async {
    if (_practica == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: No se pudo cargar la práctica'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }
    if (_isSubmitting) return;

    final tipoRaw = _practica?['TipoEjercicio'] ?? _practica?['tipoEjercicio'];
    final tipo = tipoRaw?.toString() ?? '';
    
    if (tipo.isEmpty) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error: Tipo de ejercicio no válido'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    
    print('🔍 Validando ejercicio tipo: $tipo'); // Debug

    Map<String, dynamic>? mc;
    Map<String, dynamic>? cc;
    Map<String, dynamic>? ec;

    if (tipo == 'MultipleChoice') {
      if (_selectedOpcionId == null) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Selecciona una opción'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
      mc = {'OpcionId': _selectedOpcionId};
    }

    if (tipo == 'CompletarCodigo') {
      if (_bloquesColocados.isEmpty) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ordena los bloques para continuar'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
      final bloqueIds = _bloquesColocados.map((b) {
        final id = b['BloqueId'] ?? b['bloqueId'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
        return null;
      }).whereType<int>().toList();
      
      if (bloqueIds.isEmpty) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error: No se pudieron obtener los IDs de los bloques'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
      
      cc = {'BloquesOrden': bloqueIds};
      print('📦 Bloques orden: $bloqueIds'); // Debug
    }

    if (tipo == 'EscribirCodigo') {
      final codigoUsuario = _codigoController.text.trim();
      if (codigoUsuario.isEmpty) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Escribe tu código para continuar'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }
      ec = {'CodigoUsuario': codigoUsuario};
    }

    try {
      final result = await _practicasService.validarRespuesta(
        practicaId: widget.practicaId,
        multipleChoice: mc,
        completarCodigo: cc,
        escribirCodigo: ec,
      );

      setState(() => _isSubmitting = false);

      if (result['success'] == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result['message'] ?? 'Error al validar la respuesta',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (result['success'] == true && result['resultado'] != null) {
      final res = (result['resultado'] as Map).cast<String, dynamic>();
      final esCorrecta = res['EsCorrecta'] == true || res['esCorrecta'] == true;
      final mensaje = (res['Mensaje'] ?? res['mensaje'] ?? '').toString();
      final explicacion = (res['Explicacion'] ?? res['explicacion'] ?? '').toString();
      final puntos = (res['PuntosObtenidos'] ?? res['puntosObtenidos'] ?? 0) as int;
      final yaEstabaCompletado = esCorrecta && puntos == 0 && (_progreso?['Completada'] == true || _progreso?['completada'] == true);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: esCorrecta
                        ? [
                            AppTheme.successColor.withOpacity(0.1),
                            Colors.green.shade50,
                          ]
                        : [
                            AppTheme.errorColor.withOpacity(0.1),
                            Colors.red.shade50,
                          ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono animado
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: esCorrecta
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (esCorrecta
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        esCorrecta ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Título
                    Text(
                      esCorrecta ? '¡Excelente!' : 'Inténtalo de nuevo',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: esCorrecta
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Mensaje
                    if (mensaje.isNotEmpty)
                      Text(
                        mensaje,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textPrimary,
                              height: 1.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    
                    // Explicación
                    if (explicacion.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                explicacion,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Puntos
                    if (puntos > 0) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.successColor,
                              Colors.green.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.successColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars, color: Colors.white, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              '+$puntos puntos',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (yaEstabaCompletado) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ya habías completado este ejercicio. No se suman puntos adicionales.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Botón
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: esCorrecta
                              ? AppTheme.successColor
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

        // Recargar progreso para mostrar "mi respuesta" persistida
        await _load();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('❌ Error al validar: $e'); // Debug
    }
  }

  void _resetAttempt() {
    // Permite reintentar (sin borrar backend; solo estado local)
    setState(() {
      _selectedOpcionId = null;
      _codigoController.clear();
      // Resetear CompletarCodigo
      _bloquesDisponibles = List.from(_allBloques);
      _bloquesDisponibles.shuffle(Random());
      _bloquesColocados = [];
    });
  }

  void _quitarBloqueColocado(Map<String, dynamic> bloque) {
    setState(() {
      _bloquesColocados.remove(bloque);
      if (!_bloquesDisponibles.contains(bloque)) {
        _bloquesDisponibles.add(bloque);
      }
    });
  }

  void _colocarBloque(Map<String, dynamic> bloque) {
    setState(() {
      _bloquesColocados.add(bloque);
      _bloquesDisponibles.remove(bloque);
    });
  }

  /// Construye el código reemplazando [BLOQUE_N] con los bloques colocados
  Widget _buildCodigoConBloques() {
    if (_codigoBase.isEmpty) {
      return Text(
        'Toca los bloques de abajo para completar el código',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Crear un mapa de posición -> bloque colocado
    // Usar PosicionCorrecta del bloque para mapear correctamente
    final Map<int, Map<String, dynamic>> bloquesPorPosicion = {};
    for (final bloque in _bloquesColocados) {
      final posicion = (bloque['PosicionCorrecta'] ?? bloque['posicionCorrecta']) as int?;
      if (posicion != null) {
        bloquesPorPosicion[posicion] = bloque;
      }
    }

    // Encontrar todos los placeholders [BLOQUE_1], [BLOQUE_2], etc.
    final regex = RegExp(r'\[BLOQUE_(\d+)\]');
    final matches = regex.allMatches(_codigoBase);
    
    if (matches.isEmpty) {
      // Si no hay placeholders, mostrar el código tal cual
      return SelectableText(
        _codigoBase,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFD4D4D4),
          height: 1.5,
        ),
      );
    }

    // Construir el código con widgets inline
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      // Agregar texto antes del placeholder
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: _codigoBase.substring(lastIndex, match.start),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFFD4D4D4),
          ),
        ));
      }

      // Obtener la posición del bloque (1-based)
      final posicion = int.parse(match.group(1)!);
      
      // Buscar el bloque que corresponde a esta posición
      final bloque = bloquesPorPosicion[posicion];
      
      if (bloque != null) {
        final texto = (bloque['TextoBloque'] ?? bloque['textoBloque'] ?? '').toString();

        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Material(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _quitarBloqueColocado(bloque),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        texto,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
      } else {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade600,
                  width: 1.2,
                ),
              ),
              child: Text(
                ' $posicion ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ));
      }

      lastIndex = match.end;
    }

    // Agregar el texto restante después del último placeholder
    if (lastIndex < _codigoBase.length) {
      spans.add(TextSpan(
        text: _codigoBase.substring(lastIndex),
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFD4D4D4),
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: Color(0xFFD4D4D4),
        height: 1.5,
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
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 140,
                    pinned: true,
                    backgroundColor: AppTheme.primaryColor,
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryLight,
                              AppTheme.accentColor,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _practica?['Titulo'] ?? _practica?['titulo'] ?? widget.practicaTitulo,
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildTipoBadge((_practica?['TipoEjercicio'] ?? _practica?['tipoEjercicio'] ?? '').toString()),
                                    const SizedBox(width: 10),
                                    if (_estaCompletada)
                                      _buildDoneBadge(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildEnunciadoCard(),
                          const SizedBox(height: 16),
                          _buildTipoBody(),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.06),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: _isSubmitting ? null : _submit,
                                  icon: _isSubmitting
                                      ? SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Icon(Icons.task_alt_rounded, size: 22),
                                  label: Text(
                                    _isSubmitting ? 'Comprobando…' : 'Comprobar respuesta',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _isSubmitting ? null : _resetAttempt,
                                  icon: const Icon(Icons.restart_alt_rounded, size: 22),
                                  label: const Text(
                                    'Reintentar',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryColor,
                                    side: BorderSide(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.45),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildRespuestaPreview(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEnunciadoCard() {
    final enunciado = (_practica?['Enunciado'] ?? _practica?['enunciado'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.primaryColor.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Enunciado',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: enunciado,
            styleSheet: MarkdownStyleSheet(
              p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
              strong: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                backgroundColor: Colors.transparent,
                color: const Color(0xFF1F2937),
                decoration: TextDecoration.none,
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFFFCFDFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              codeblockPadding: const EdgeInsets.all(12),
            ),
            syntaxHighlighter: CSharpSyntaxHighlighter(),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoBody() {
    final tipo = (_practica?['TipoEjercicio'] ?? _practica?['tipoEjercicio'] ?? '').toString();

    switch (tipo) {
      case 'MultipleChoice':
        return _buildMultipleChoice();
      case 'CompletarCodigo':
        return _buildCompletarCodigo();
      case 'EscribirCodigo':
        return _buildEscribirCodigo();
      default:
        return Text(
          'Tipo de ejercicio no soportado: $tipo',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.errorColor),
        );
    }
  }

  int? _opcionIdDe(Map<String, dynamic> m) {
    final v = m['OpcionId'] ?? m['opcionId'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Widget _buildMultipleChoice() {
    final opcionesRaw =
        (_practica?['Opciones'] ?? _practica?['opciones']) as List<dynamic>? ??
            [];
    final pistaOpcional =
        (_practica?['PistaOpcional'] ?? _practica?['pistaOpcional'] ?? '')
            .toString();

    final opciones = <Map<String, dynamic>>[];
    for (final o in opcionesRaw) {
      if (o is! Map) continue;
      final m = Map<String, dynamic>.from(o);
      if (_opcionIdDe(m) != null) opciones.add(m);
    }

    if (opciones.isEmpty) {
      return _buildInfoEmpty('Este ejercicio no tiene opciones configuradas.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.quiz_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Opción múltiple',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige una respuesta y pulsa Comprobar.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pistaOpcional.trim().isNotEmpty) ...[
          _buildPistaCard(pistaOpcional),
          const SizedBox(height: 14),
        ],
        ...List.generate(opciones.length, (index) {
          final m = opciones[index];
          final opcionId = _opcionIdDe(m)!;
          final texto =
              (m['TextoOpcion'] ?? m['textoOpcion'] ?? '').toString();
          final selected = _selectedOpcionId == opcionId;
          final letra = String.fromCharCode(65 + index);

          return Padding(
            padding: EdgeInsets.only(
              bottom: index == opciones.length - 1 ? 0 : 10,
            ),
            child: _buildOpcionMultipleChoiceTile(
              letra: letra,
              texto: texto,
              selected: selected,
              onTap: () => setState(() => _selectedOpcionId = opcionId),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOpcionMultipleChoiceTile({
    required String letra,
    required String texto,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppTheme.primaryColor.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: selected ? 14 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryColor : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    letra,
                    style: TextStyle(
                      color: selected ? Colors.white : AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      texto,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? AppTheme.primaryDark
                                : AppTheme.textPrimary,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: selected ? 1 : 0.85,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletarCodigo() {
    if (_allBloques.isEmpty) {
      return _buildInfoEmpty('Este ejercicio no tiene bloques configurados.');
    }

    final pistaOpcional =
        (_practica?['PistaOpcional'] ?? _practica?['pistaOpcional'] ?? '').toString();
    final huecosPendientes = _contarHuecosPendientesCompletarCodigo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.view_module_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Completar código',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca un fragmento para insertarlo en su hueco. Toca un bloque morado en el código para quitarlo y devolverlo aquí.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (pistaOpcional.trim().isNotEmpty) ...[
          _buildPistaCard(pistaOpcional),
          const SizedBox(height: 14),
        ],
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade800),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: const Color(0xFF2D2D2D),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5F57),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEBC2E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF28C840),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.code_rounded, size: 18, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        huecosPendientes > 0
                            ? '$huecosPendientes hueco${huecosPendientes == 1 ? '' : 's'} por llenar'
                            : 'Huecos completos',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.sizeOf(context).width - 40,
                    ),
                    child: _buildCodigoConBloques(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'Fragmentos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_bloquesDisponibles.length}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_bloquesDisponibles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No quedan fragmentos sueltos. Toca un bloque morado en el código para quitarlo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _bloquesDisponibles
                .map((b) => _buildBloqueDisponibleChip(b))
                .toList(),
          ),
      ],
    );
  }

  int _contarHuecosPendientesCompletarCodigo() {
    if (_codigoBase.isEmpty) return 0;
    final regex = RegExp(r'\[BLOQUE_(\d+)\]');
    final posiciones = regex
        .allMatches(_codigoBase)
        .map((m) => int.tryParse(m.group(1) ?? '') ?? 0)
        .toSet();
    if (posiciones.isEmpty) return 0;
    final Map<int, bool> lleno = {};
    for (final b in _bloquesColocados) {
      final p = b['PosicionCorrecta'] ?? b['posicionCorrecta'];
      final pi = p is int ? p : int.tryParse(p.toString());
      if (pi != null) lleno[pi] = true;
    }
    var n = 0;
    for (final pos in posiciones) {
      if (pos > 0 && lleno[pos] != true) n++;
    }
    return n;
  }

  Widget _buildBloqueDisponibleChip(Map<String, dynamic> bloque) {
    final texto = (bloque['TextoBloque'] ?? bloque['textoBloque'] ?? '').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _colocarBloque(bloque),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  texto,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Barra tipo IDE (misma línea visual que Completar código).
  Widget _buildDarkCodeEditorChrome({
    required String title,
    required Widget body,
    EdgeInsetsGeometry bodyPadding = const EdgeInsets.fromLTRB(14, 14, 14, 16),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: const Color(0xFF2D2D2D),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5F57),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEBC2E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFF28C840),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.code_rounded, size: 18, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: bodyPadding,
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _buildEscribirCodigo() {
    final codigo = (_practica?['Codigo'] ?? _practica?['codigo']) as Map<dynamic, dynamic>?;
    final codigoBase = (codigo?['CodigoBase'] ?? codigo?['codigoBase'] ?? '').toString();
    var pistaOpcional = (codigo?['PistaOpcional'] ?? codigo?['pistaOpcional'] ?? '').toString().trim();
    if (pistaOpcional.isEmpty) {
      pistaOpcional =
          (_practica?['PistaOpcional'] ?? _practica?['pistaOpcional'] ?? '').toString().trim();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escribir código',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    codigoBase.trim().isNotEmpty
                        ? 'Completa el código en el editor inferior a partir del fragmento de referencia. Puedes copiar texto seleccionándolo.'
                        : 'Escribe tu solución completa en el editor. Usa el mismo estilo que en los ejemplos del curso.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (pistaOpcional.isNotEmpty) ...[
          _buildPistaCard(pistaOpcional),
          const SizedBox(height: 14),
        ],
        if (codigoBase.trim().isNotEmpty) ...[
          _buildDarkCodeEditorChrome(
            title: 'Código base (solo lectura)',
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.sizeOf(context).width - 40,
                ),
                child: _buildColoredCode(codigoBase),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _buildDarkCodeEditorChrome(
          title: 'Tu solución',
          body: TextField(
            controller: _codigoController,
            minLines: 10,
            maxLines: 22,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Color(0xFFD4D4D4),
              height: 1.45,
            ),
            cursorColor: AppTheme.primaryColor,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFF252526),
              hoverColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: '// Escribe tu solución aquí…',
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
          bodyPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        ),
      ],
    );
  }

  Widget _buildColoredCode(String code) {
    // Palabras clave de C#
    final keywords = [
      'using', 'namespace', 'class', 'public', 'private', 'protected', 'internal',
      'static', 'void', 'int', 'string', 'bool', 'double', 'float', 'char',
      'var', 'const', 'readonly', 'async', 'await', 'return', 'if', 'else',
      'for', 'foreach', 'while', 'do', 'switch', 'case', 'break', 'continue',
      'try', 'catch', 'finally', 'throw', 'new', 'this', 'base', 'null',
      'true', 'false', 'enum', 'interface', 'abstract', 'sealed', 'partial',
      'override', 'virtual', 'get', 'set', 'ref', 'out', 'params', 'in',
    ];

    // Tipos de datos comunes
    final types = [
      'List', 'Dictionary', 'Array', 'IEnumerable', 'Task', 'Action', 'Func',
      'DateTime', 'TimeSpan', 'Guid', 'Object', 'Exception',
    ];

    // Dividir el código en líneas
    final lines = code.split('\n');
    
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          return _buildColoredLine(line, keywords, types);
        }).toList(),
      ),
    );
  }

  Widget _buildColoredLine(String line, List<String> keywords, List<String> types) {
    if (line.trim().isEmpty) {
      return const SizedBox(height: 4);
    }

    // Línea con colores sintácticos
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Color(0xFFD4D4D4),
            height: 1.5,
          ),
          children: _parseLineWithColors(line, keywords, types),
        ),
      ),
    );
  }

  List<TextSpan> _parseLineWithColors(String line, List<String> keywords, List<String> types) {
    final spans = <TextSpan>[];
    int i = 0;
    
    while (i < line.length) {
      // Detectar strings entre comillas dobles
      if (line[i] == '"') {
        final start = i;
        i++;
        while (i < line.length && line[i] != '"') {
          if (line[i] == '\\' && i + 1 < line.length) {
            i += 2; // Escapar caracteres
          } else {
            i++;
          }
        }
        if (i < line.length) i++;
        spans.add(TextSpan(
          text: line.substring(start, i),
          style: const TextStyle(
            color: Color(0xFFCE9178), // Naranja para strings
          ),
        ));
        continue;
      }
      
      // Detectar strings entre comillas simples
      if (line[i] == "'" && i + 1 < line.length) {
        final start = i;
        i++;
        if (line[i] == '\\' && i + 1 < line.length) {
          i += 2;
        } else {
          i++;
        }
        if (i < line.length && line[i] == "'") i++;
        spans.add(TextSpan(
          text: line.substring(start, i),
          style: const TextStyle(
            color: Color(0xFFCE9178), // Naranja para strings
          ),
        ));
        continue;
      }
      
      // Detectar comentarios de línea
      if (i + 1 < line.length && line[i] == '/' && line[i + 1] == '/') {
        spans.add(TextSpan(
          text: line.substring(i),
          style: const TextStyle(
            color: Color(0xFF6A9955), // Verde para comentarios
          ),
        ));
        break;
      }
      
      // Detectar palabras (identificadores, keywords, números)
      if (RegExp(r'[a-zA-Z_$]').hasMatch(line[i])) {
        final start = i;
        while (i < line.length && RegExp(r'[a-zA-Z0-9_$]').hasMatch(line[i])) {
          i++;
        }
        final word = line.substring(start, i);
        final trimmedWord = word.trim();
        
        // Palabras clave (azul)
        if (keywords.contains(trimmedWord)) {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: Color(0xFF569CD6), // Azul para palabras clave
              fontWeight: FontWeight.w500,
            ),
          ));
        }
        // Tipos (turquesa)
        else if (types.contains(trimmedWord)) {
          spans.add(TextSpan(
            text: word,
            style: const TextStyle(
              color: Color(0xFF4EC9B0), // Turquesa para tipos
            ),
          ));
        }
        // Texto normal
        else {
          spans.add(TextSpan(text: word));
        }
        continue;
      }
      
      // Detectar números
      if (RegExp(r'[0-9]').hasMatch(line[i])) {
        final start = i;
        while (i < line.length && (RegExp(r'[0-9.]').hasMatch(line[i]) || 
                                   (line[i] == 'f' || line[i] == 'F' || 
                                    line[i] == 'd' || line[i] == 'D' || 
                                    line[i] == 'm' || line[i] == 'M'))) {
          i++;
        }
        spans.add(TextSpan(
          text: line.substring(start, i),
          style: const TextStyle(
            color: Color(0xFFB5CEA8), // Verde claro para números
          ),
        ));
        continue;
      }
      
      // Caracteres especiales y espacios
      spans.add(TextSpan(text: line[i]));
      i++;
    }

    return spans;
  }

  Widget _buildPistaCard(String pista) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Botón para mostrar/ocultar pista
          InkWell(
            onTap: () {
              setState(() {
                _mostrarPista = !_mostrarPista;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '💡 Ver pista (opcional)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                    ),
                  ),
                  Icon(
                    _mostrarPista
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Contenido de la pista (expandible)
          if (_mostrarPista) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.primaryColor.withOpacity(0.2),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                pista,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRespuestaPreview() {
    final respuestaRaw = _progreso?['RespuestaUsuario'] ?? _progreso?['respuestaUsuario'];
    if (respuestaRaw == null || respuestaRaw.toString().trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ya respondiste este ejercicio. Puedes volver a verlo y reintentar cuando quieras.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoBadge(String tipo) {
    IconData icon;
    String text;
    switch (tipo) {
      case 'MultipleChoice':
        icon = Icons.quiz_rounded;
        text = 'Opción múltiple';
        break;
      case 'CompletarCodigo':
        icon = Icons.code_rounded;
        text = 'Completar código';
        break;
      case 'EscribirCodigo':
        icon = Icons.edit_note_rounded;
        text = 'Escribir código';
        break;
      default:
        icon = Icons.assignment_rounded;
        text = tipo.isEmpty ? 'Práctica' : tipo;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            'Completado',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoEmpty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

