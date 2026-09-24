import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class CSharpSyntaxHighlighter extends SyntaxHighlighter {
  static final RegExp _tokenRegExp = RegExp(
    r'''("([^"\\]|\\.)*")|('([^'\\]|\\.)*')|(\b\d+(\.\d+)?([fFdDmM])?\b)|(//.*$)|\b(using|namespace|class|public|private|protected|internal|static|void|int|string|bool|double|float|char|var|const|readonly|async|await|return|if|else|for|foreach|while|do|switch|case|break|continue|try|catch|finally|throw|new|this|base|null|true|false|enum|interface|abstract|sealed|partial|override|virtual|get|set|ref|out|params|in)\b''',
    multiLine: true,
  );

  CSharpSyntaxHighlighter();

  @override
  TextSpan format(String source) {
    final children = <TextSpan>[];
    int currentIndex = 0;

    for (final match in _tokenRegExp.allMatches(source)) {
      if (match.start > currentIndex) {
        children.add(TextSpan(text: source.substring(currentIndex, match.start)));
      }

      final token = source.substring(match.start, match.end);
      children.add(TextSpan(text: token, style: _styleForToken(match, token)));
      currentIndex = match.end;
    }

    if (currentIndex < source.length) {
      children.add(TextSpan(text: source.substring(currentIndex)));
    }

    return TextSpan(
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.5,
        decoration: TextDecoration.none,
      ),
      children: children,
    );
  }

  TextStyle _styleForToken(RegExpMatch match, String token) {
    // Grupos por orden en la regex:
    // 1-2: string doble, 3-4: string simple, 5-7: número, 8: comentario, 9: keyword
    if (match.group(1) != null || match.group(3) != null) {
      return const TextStyle(color: Color(0xFFB45309)); // strings
    }
    if (match.group(5) != null) {
      return const TextStyle(color: Color(0xFF0F766E)); // números
    }
    if (match.group(8) != null) {
      return const TextStyle(color: Color(0xFF64748B)); // comentarios
    }
    if (match.group(9) != null) {
      return const TextStyle(
        color: Color(0xFF4F46E5), // keywords
        fontWeight: FontWeight.w600,
      );
    }
    return const TextStyle(color: Color(0xFF1F2937));
  }
}
