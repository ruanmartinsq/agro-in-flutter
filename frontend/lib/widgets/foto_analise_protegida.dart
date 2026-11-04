import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';

/// Port de src/components/FotoAnaliseProtegida.tsx — baixa a foto da análise
/// com o token (rota protegida) e exibe a imagem.
class FotoAnaliseProtegida extends StatefulWidget {
  const FotoAnaliseProtegida({
    super.key,
    required this.analiseId,
    this.width,
    this.height,
    this.borderRadius,
  });

  final int analiseId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<FotoAnaliseProtegida> createState() => _FotoAnaliseProtegidaState();
}

class _FotoAnaliseProtegidaState extends State<FotoAnaliseProtegida> {
  Uint8List? _bytes;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant FotoAnaliseProtegida oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analiseId != widget.analiseId) {
      setState(() {
        _bytes = null;
        _erro = false;
      });
      _carregar();
    }
  }

  Future<void> _carregar() async {
    try {
      final res = await api.get<List<int>>(
        '/analise-foliar/${widget.analiseId}/imagem',
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(res.data ?? const []));
    } catch (_) {
      if (mounted) setState(() => _erro = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget conteudo;
    if (_erro) {
      conteudo = Container(
        color: const Color(0xFFE8ECE5),
        alignment: Alignment.center,
        child: const Icon(
          LucideIcons.imageOff,
          size: 20,
          color: Color(0xFF7A877A),
        ),
      );
    } else if (_bytes == null) {
      conteudo = Container(
        color: const Color(0xFFE8ECE5),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF4B7152),
          ),
        ),
      );
    } else {
      conteudo = Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      );
    }
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: conteudo,
      ),
    );
  }
}
