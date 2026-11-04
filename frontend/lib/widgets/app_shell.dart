import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';

/// Port de src/components/Sidebar.tsx.
/// Em telas >= 1024px (lg) a sidebar fica fixa à esquerda (216px);
/// abaixo disso aparece o cabeçalho verde com botão de menu e a sidebar vira drawer (272px).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const double lgBreakpoint = 1024;

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    if (largura >= lgBreakpoint) {
      return Scaffold(
        backgroundColor: AgroColors.canvas,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: 216, child: Sidebar(desktop: true)),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AgroColors.canvas,
      drawerScrimColor: AgroColors.overlay,
      drawer: const Drawer(
        width: 272,
        shape: RoundedRectangleBorder(),
        backgroundColor: AgroColors.sidebar,
        child: Sidebar(desktop: false),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Builder(
          builder: (ctx) =>
              _MobileHeader(onMenu: () => Scaffold.of(ctx).openDrawer()),
        ),
      ),
      body: child,
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgroColors.sidebar,
        border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
        boxShadow: [
          BoxShadow(
            color: Color(0x290F5317),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Material(
                color: Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onMenu,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      LucideIcons.menu,
                      size: 21,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () => context.go('/dashboard'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logo.png', width: 36, height: 36),
                        const SizedBox(width: 10),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agro.in',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1,
                                letterSpacing: -.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'GESTÃO RURAL',
                              style: TextStyle(
                                color: Color(0xFF99C9A2),
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemNav {
  const _ItemNav(this.key, this.label, this.icone);
  final String key;
  final String label;
  final IconData icone;
}

const _nav = <_ItemNav>[
  _ItemNav('dashboard', 'Dashboard', LucideIcons.layoutDashboard),
  _ItemNav('propriedade', 'Propriedade', LucideIcons.map),
  _ItemNav('financeiro', 'Financeiro', LucideIcons.walletCards),
  _ItemNav('producao', 'Produção', LucideIcons.sprout),
  _ItemNav('estoque', 'Estoque', LucideIcons.package),
  _ItemNav('meta', 'Metas', LucideIcons.target),
  _ItemNav('analise-foliar', 'Análise foliar', LucideIcons.leaf),
  _ItemNav('relatorios', 'Relatórios', LucideIcons.fileChartColumn),
  _ItemNav('perfil', 'Perfil', LucideIcons.userRound),
];

class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.desktop});
  final bool desktop;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String _busca = '';

  void _irPara(String path) {
    if (!widget.desktop) Navigator.of(context).maybePop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final pathname = GoRouterState.of(context).uri.path;
    final termo = _busca.trim().toLowerCase();
    final itens = _nav
        .where((i) => i.label.toLowerCase().contains(termo))
        .toList();
    final assistenteAtivo = pathname == '/assistente';

    return Container(
      decoration: const BoxDecoration(
        color: AgroColors.sidebar,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _irPara('/dashboard'),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: widget.desktop ? 64 : 48,
                          height: widget.desktop ? 64 : 48,
                        ),
                        if (!widget.desktop) ...[
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agro.in',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: -.7,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'GESTÃO RURAL',
                                style: TextStyle(
                                  color: AgroColors.sidebarSubtitle,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!widget.desktop)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        LucideIcons.x,
                        size: 19,
                        color: Colors.white.withValues(alpha: .7),
                      ),
                      tooltip: 'Fechar menu',
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.search,
                      size: 14,
                      color: Colors.white.withValues(alpha: .4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _busca = v),
                        cursorColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'Pesquisar',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: .38),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final item in itens)
                      _NavButton(
                        item: item,
                        ativo:
                            pathname == '/${item.key}' ||
                            (item.key == 'analise-foliar' &&
                                pathname.startsWith('/analise-foliar/')),
                        onTap: () => _irPara('/${item.key}'),
                      ),
                    if (itens.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        child: Text(
                          'Nenhum módulo encontrado.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.8,
                            color: Colors.white.withValues(alpha: .45),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withValues(alpha: .1)),
              const SizedBox(height: 16),
              Material(
                color: assistenteAtivo ? AgroColors.mint : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: assistenteAtivo
                        ? AgroColors.mint
                        : AgroColors.assistantBorder,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _irPara('/assistente'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                (assistenteAtivo
                                        ? AgroColors.assistantActiveText
                                        : AgroColors.mint)
                                    .withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            LucideIcons.bot,
                            size: 16,
                            color: assistenteAtivo
                                ? AgroColors.assistantActiveText
                                : AgroColors.mint,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Assistente Agro.in',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: assistenteAtivo
                                ? AgroColors.assistantActiveText
                                : AgroColors.mint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  const _NavButton({
    required this.item,
    required this.ativo,
    required this.onTap,
  });
  final _ItemNav item;
  final bool ativo;
  final VoidCallback onTap;

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ativo = widget.ativo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ativo
                  ? Colors.white.withValues(alpha: .08)
                  : (_hover
                        ? Colors.white.withValues(alpha: .06)
                        : Colors.transparent),
              border: Border(
                left: BorderSide(
                  color: ativo
                      ? AgroColors.sidebarActiveBorder
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.item.icone,
                  size: 16,
                  color: ativo
                      ? AgroColors.mint
                      : Colors.white.withValues(alpha: _hover ? .75 : .44),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                    color: ativo || _hover
                        ? Colors.white
                        : Colors.white.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
