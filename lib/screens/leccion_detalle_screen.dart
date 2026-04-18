import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/lecciones_service.dart';
import '../services/progreso_service.dart';
import '../services/practicas_service.dart';
import 'practica_detalle_screen.dart';

class LeccionDetalleScreen extends StatefulWidget {
  final int leccionId;
  final String leccionTitulo;
  final int cursoId;

  const LeccionDetalleScreen({
    super.key,
    required this.leccionId,
    required this.leccionTitulo,
    required this.cursoId,
  });

  @override
  State<LeccionDetalleScreen> createState() => _LeccionDetalleScreenState();
}

class _LeccionDetalleScreenState extends State<LeccionDetalleScreen>
    with SingleTickerProviderStateMixin {
  final _leccionesService = LeccionesService();
  final _progresoService = ProgresoService();
  final _practicasService = PracticasService();
  Map<String, dynamic>? _leccionData;
  List<dynamic> _practicas = [];
  bool _isLoading = true;
  bool _isCompletada = false;
  bool _isMarkingComplete = false;
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
    _progresoService.actualizarUltimoAcceso(widget.leccionId);
    _loadLeccion();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadLeccion({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _isLoading = true;
      });
    }

    await _progresoService.actualizarUltimoAcceso(widget.leccionId);

    // Cargar lección, progreso y prácticas en paralelo
    final results = await Future.wait([
      _leccionesService.getLeccion(widget.leccionId),
      _progresoService.obtenerProgresoLeccion(widget.leccionId),
      _practicasService.getPracticasByLeccion(widget.leccionId),
    ]);

    final leccionResult = results[0];
    final progresoResult = results[1];
    final practicasResult = results[2];

    if (leccionResult['success'] == true && leccionResult['leccion'] != null) {
      // Verificar si está completada
      bool completada = false;
      if (progresoResult['success'] == true && progresoResult['progreso'] != null) {
        final progreso = progresoResult['progreso'] as Map<String, dynamic>;
        completada = progreso['Completada'] == true || progreso['completada'] == true;
      }

      // Obtener prácticas (del resultado o de la lección)
      List<dynamic> practicas = [];
      if (practicasResult['success'] == true && practicasResult['practicas'] != null) {
        practicas = practicasResult['practicas'] as List;
      } else if (leccionResult['leccion']?['Practicas'] != null) {
        practicas = leccionResult['leccion']['Practicas'] as List;
      }

      setState(() {
        _leccionData = leccionResult['leccion'];
        _practicas = practicas;
        _isCompletada = completada;
        _isLoading = false;
      });

      final tituloVista = (_leccionData?['Titulo'] ??
              _leccionData?['titulo'] ??
              widget.leccionTitulo)
          .toString();
      await _progresoService.guardarUltimaLeccionVista(
        leccionId: widget.leccionId,
        cursoId: widget.cursoId,
        titulo: tituloVista,
      );

      // Cargar siguiente lección
      _cargarSiguienteLeccion();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(leccionResult['message'] ?? 'Error al cargar la lección'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
    _animationController.forward();
  }

  Future<void> _cargarSiguienteLeccion() async {
    try {
      // Obtener todas las lecciones del curso
      final result = await _leccionesService.getLeccionesByCurso(widget.cursoId);
      
      if (result['success'] == true && result['lecciones'] != null) {
        final lecciones = (result['lecciones'] as List).cast<Map<String, dynamic>>();
        
        // Obtener el orden de la lección actual
        final ordenActual = _leccionData?['Orden'] ?? _leccionData?['orden'];
        
        if (ordenActual != null) {
          // Buscar la siguiente lección (orden mayor al actual)
          final siguiente = lecciones.firstWhere(
            (l) => (l['Orden'] ?? l['orden']) > ordenActual,
            orElse: () => <String, dynamic>{},
          );
          
          if (siguiente.isNotEmpty) {
            setState(() {
              _siguienteLeccion = siguiente;
            });
          }
        }
      }
    } catch (e) {
      // Silenciar errores, no es crítico
      print('Error al cargar siguiente lección: $e');
    }
  }

  void _irASiguienteLeccion() {
    if (_siguienteLeccion == null) return;
    
    final siguienteId = _siguienteLeccion!['LeccionId'] ?? _siguienteLeccion!['leccionId'];
    final siguienteTitulo = _siguienteLeccion!['Titulo'] ?? _siguienteLeccion!['titulo'] ?? 'Siguiente lección';
    
    if (siguienteId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LeccionDetalleScreen(
            leccionId: siguienteId is int ? siguienteId : int.parse(siguienteId.toString()),
            leccionTitulo: siguienteTitulo.toString(),
            cursoId: widget.cursoId,
          ),
        ),
      );
    }
  }

  Future<void> _marcarComoCompletada() async {
    if (_isMarkingComplete || _isCompletada) return;

    setState(() {
      _isMarkingComplete = true;
    });

    final result = await _progresoService.marcarLeccionCompletada(widget.leccionId);

    if (result['success'] == true) {
      setState(() {
        _isCompletada = true;
        _isMarkingComplete = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('¡Lección completada! +10 puntos'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      setState(() {
        _isMarkingComplete = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al marcar como completada'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Código copiado al portapapeles'),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _tieneDescripcionCorta() {
    final s = _leccionData?['DescripcionCorta'] ?? _leccionData?['descripcionCorta'];
    return s != null && s.toString().trim().isNotEmpty;
  }

  bool _tieneContenidoBreve() {
    final s = _leccionData?['ContenidoBreve'] ?? _leccionData?['contenidoBreve'];
    return s != null && s.toString().trim().isNotEmpty;
  }

  bool _tieneCodigoEjemplo() {
    final s = _leccionData?['CodigoEjemplo'] ?? _leccionData?['codigoEjemplo'];
    return s != null && s.toString().trim().isNotEmpty;
  }

  MarkdownStyleSheet _markdownLeccion() {
    final t = Theme.of(context).textTheme;
    return MarkdownStyleSheet(
      p: t.bodyLarge?.copyWith(height: 1.65, color: AppTheme.textPrimary),
      h1: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryColor,
        height: 1.25,
      ),
      h2: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppTheme.primaryColor,
        height: 1.3,
      ),
      h3: t.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppTheme.primaryDark,
        height: 1.35,
      ),
      strong: t.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
      em: t.bodyLarge?.copyWith(
        fontStyle: FontStyle.italic,
        color: AppTheme.textSecondary,
      ),
      blockquote: t.bodyMedium?.copyWith(
        color: AppTheme.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: AppTheme.primaryColor, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      listBullet: t.bodyLarge?.copyWith(color: AppTheme.primaryColor),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      a: t.bodyLarge?.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
        color: AppTheme.primaryDark,
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      codeblockPadding: const EdgeInsets.all(14),
    );
  }

  Widget _buildSeccionTitulo(BuildContext context, String titulo, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          titulo,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildEstadoLeccion(BuildContext context) {
    if (_isCompletada) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.successColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(
              'Lección completada',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isMarkingComplete ? null : _marcarComoCompletada,
        icon: _isMarkingComplete
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.task_alt_rounded),
        label: Text(
          _isMarkingComplete ? 'Guardando…' : 'Marcar como completada',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildTarjetaResumen(BuildContext context) {
    final data = _leccionData?['DescripcionCorta'] ??
        _leccionData?['descripcionCorta'] ??
        '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: MarkdownBody(
                  data: data.toString(),
                  styleSheet: MarkdownStyleSheet(
                    p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.55,
                          color: AppTheme.textPrimary,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaMarkdown(BuildContext context) {
    final data = _leccionData?['ContenidoBreve'] ??
        _leccionData?['contenidoBreve'] ??
        '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: MarkdownBody(
        data: data.toString(),
        styleSheet: _markdownLeccion(),
      ),
    );
  }

  Widget _buildTarjetaCodigo(BuildContext context) {
    final codigo = _leccionData?['CodigoEjemplo'] ??
        _leccionData?['codigoEjemplo'] ??
        '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeccionTitulo(context, 'Código de ejemplo', Icons.terminal_rounded),
        const SizedBox(height: 10),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: const Color(0xFF2D2D2D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5F57),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEBC2E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF28C840),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'C#',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(codigo.toString()),
                        icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                        tooltip: 'Copiar',
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: SelectionArea(
                  child: _buildColoredCode(codigo.toString()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCtaSiguiente(BuildContext context) {
    final t = _siguienteLeccion!['Titulo'] ??
        _siguienteLeccion!['titulo'] ??
        'Siguiente';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _irASiguienteLeccion,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(
          'Siguiente: $t',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () => _loadLeccion(silencioso: true),
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
                          _leccionData?['Titulo'] ??
                              _leccionData?['titulo'] ??
                              widget.leccionTitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEstadoLeccion(context),
                              const SizedBox(height: 20),
                              if (_tieneDescripcionCorta()) ...[
                                _buildSeccionTitulo(context, 'Resumen', Icons.lightbulb_outline_rounded),
                                const SizedBox(height: 10),
                                _buildTarjetaResumen(context),
                                const SizedBox(height: 24),
                              ],
                              if (_tieneContenidoBreve()) ...[
                                _buildSeccionTitulo(context, 'Contenido', Icons.article_outlined),
                                const SizedBox(height: 10),
                                _buildTarjetaMarkdown(context),
                                const SizedBox(height: 24),
                              ],
                              if (_tieneCodigoEjemplo()) ...[
                                _buildTarjetaCodigo(context),
                                const SizedBox(height: 24),
                              ],
                              if (_practicas.isNotEmpty) ...[
                                _buildSeccionTitulo(context, 'Prácticas', Icons.quiz_outlined),
                                const SizedBox(height: 10),
                                ..._practicas.map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildPracticaCard(context, p),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_siguienteLeccion != null) _buildCtaSiguiente(context),
                            ],
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        return _buildColoredLine(line, keywords, types);
      }).toList(),
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
            fontSize: 14,
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

  Widget _buildPracticaCard(BuildContext context, Map<String, dynamic> practica) {
    final tipoEjercicio = practica['TipoEjercicio'] ?? practica['tipoEjercicio'] ?? '';
    final titulo = practica['Titulo'] ?? practica['titulo'] ?? 'Práctica sin título';
    final isActive = practica['Activo'] == true || practica['activo'] == true;

    IconData iconData;
    Color color;
    String tipoTexto;

    switch (tipoEjercicio) {
      case 'MultipleChoice':
        iconData = Icons.quiz_rounded;
        color = AppTheme.primaryColor;
        tipoTexto = 'Opción múltiple';
        break;
      case 'CompletarCodigo':
        iconData = Icons.code_rounded;
        color = Colors.orange;
        tipoTexto = 'Completar código';
        break;
      case 'EscribirCodigo':
        iconData = Icons.edit_note_rounded;
        color = AppTheme.successColor;
        tipoTexto = 'Escribir código';
        break;
      default:
        iconData = Icons.assignment_rounded;
        color = AppTheme.textSecondary;
        tipoTexto = 'Práctica';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            final practicaId = practica['PracticaId'] ?? practica['practicaId'];
            if (practicaId != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PracticaDetalleScreen(
                    practicaId: practicaId is int
                        ? practicaId
                        : int.parse(practicaId.toString()),
                    practicaTitulo: practica['Titulo'] ??
                        practica['titulo'] ??
                        'Práctica',
                  ),
                ),
              );
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
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    iconData,
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
                        titulo,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tipoTexto,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(width: 8),
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
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
}
