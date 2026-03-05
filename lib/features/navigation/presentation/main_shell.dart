import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/wayqui_colors.dart';

/// Shell de navegación principal — envuelve las 4 tabs con BottomNavigationBar.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    final idx    = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _WayquiNavBar(
        currentIndex: idx,
        colors:       colors,
        theme:        theme,
        onTap:        _onTap,
      ),
    );
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      // Si ya estamos en la pestaña activa, vuelve al root
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _WayquiNavBar extends StatelessWidget {
  final int          currentIndex;
  final WayquiColors colors;
  final ThemeData    theme;
  final void Function(int) onTap;

  const _WayquiNavBar({
    required this.currentIndex,
    required this.colors,
    required this.theme,
    required this.onTap,
  });

  static const _items = [
    _NavItem(icon: FontAwesomeIcons.houseChimney,    activeIcon: FontAwesomeIcons.houseChimney,    label: 'Inicio'),
    _NavItem(icon: FontAwesomeIcons.clockRotateLeft, activeIcon: FontAwesomeIcons.clockRotateLeft, label: 'Actividad'),
    _NavItem(icon: FontAwesomeIcons.userGroup,       activeIcon: FontAwesomeIcons.userGroup,       label: 'Contactos'),
    _NavItem(icon: FontAwesomeIcons.circleUser,      activeIcon: FontAwesomeIcons.circleUser,      label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:  theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top:  false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: _items.asMap().entries.map((e) {
              final i    = e.key;
              final item = e.value;
              final active = i == currentIndex;
              return Expanded(
                child: _NavBarItem(
                  item:   item,
                  active: active,
                  color:  active ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  onTap:  () => onTap(i),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _NavBarItem extends StatelessWidget {
  final _NavItem    item;
  final bool        active;
  final Color       color;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:    onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve:    Curves.easeInOut,
              padding:  EdgeInsets.symmetric(
                horizontal: active ? 16 : 0,
                vertical:   4,
              ),
              decoration: active
                  ? BoxDecoration(
                      color:        color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    )
                  : null,
              child: FaIcon(
                active ? item.activeIcon : item.icon,
                size:  18,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: theme.textTheme.labelSmall!.copyWith(
                color:      color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                fontSize:   10,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
