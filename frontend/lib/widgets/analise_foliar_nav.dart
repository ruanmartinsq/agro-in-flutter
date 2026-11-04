import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Port de src/components/AnaliseFoliarNav.tsx — abas Diagnóstico / Quarentenas / Vistoria de área.
class AnaliseFoliarNav extends StatelessWidget {
  const AnaliseFoliarNav({super.key});

  static const _itens = [
    (
      para: '/analise-foliar',
      fim: true,
      rotulo: 'Diagnóstico',
      curto: 'Diagnóstico',
      icone: LucideIcons.camera,
    ),
    (
      para: '/analise-foliar/quarentenas',
      fim: false,
      rotulo: 'Quarentenas',
      curto: 'Quarentena',
      icone: LucideIcons.shieldCheck,
    ),
    (
      para: '/analise-foliar/vistorias',
      fim: false,
      rotulo: 'Vistoria de área',
      curto: 'Área',
      icone: LucideIcons.mapPinned,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final sm = MediaQuery.sizeOf(context).width >= 640;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDCE3D8)),
      ),
      child: Row(
        children: [
          for (final (i, item) in _itens.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Builder(
                builder: (context) {
                  final ativo = item.fim
                      ? path == item.para
                      : path.startsWith(item.para);
                  return Material(
                    color: ativo ? const Color(0xFF1F5B3A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: const Color(0xFFF1F5EE),
                      onTap: () => context.go(item.para),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: sm ? 14 : 4,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                item.icone,
                                size: 15,
                                color: ativo
                                    ? Colors.white
                                    : const Color(0xFF607064),
                              ),
                              SizedBox(width: sm ? 8 : 4),
                              Flexible(
                                child: Text(
                                  sm ? item.rotulo : item.curto,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: sm ? 12 : 10,
                                    fontWeight: FontWeight.w700,
                                    color: ativo
                                        ? Colors.white
                                        : const Color(0xFF607064),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
