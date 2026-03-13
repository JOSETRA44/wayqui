import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/wayqui_colors.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';

/// Shell de navegación principal — envuelve las 4 tabs con BottomNavigationBar.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final colors     = theme.extension<WayquiColors>()!;
    final idx        = navigationShell.currentIndex;
    final unread     = ref.watch(unreadCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _WayquiNavBar(
        currentIndex: idx,
        colors:       colors,
        theme:        theme,
        unreadCount:  unread,
        onTap:        _onTap,
      ),
    );
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
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
  final int          unreadCount;
  final void Function(int) onTap;

  const _WayquiNavBar({
    required this.currentIndex,
    required this.colors,
    required this.theme,
    required this.unreadCount,
    required this.onTap,
  });

  // Activity tab is index 1 — badge shows when there are unread notifications.
  static const _kActivityIndex = 1;

  static const _items = [
    _NavItem(icon: FontAwesomeIcons.houseChimney,    label: 'Inicio'),
    _NavItem(icon: FontAwesomeIcons.clockRotateLeft, label: 'Actividad'),
    _NavItem(icon: FontAwesomeIcons.userGroup,       label: 'Contactos'),
    _NavItem(icon: FontAwesomeIcons.circleUser,      label: 'Perfil'),
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
              final i      = e.key;
              final item   = e.value;
              final active = i == currentIndex;
              return Expanded(
                child: _NavBarItem(
                  item:      item,
                  active:    active,
                  showBadge: i == _kActivityIndex && unreadCount > 0,
                  color:     active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  onTap:     () => onTap(i),
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
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

class _NavBarItem extends StatelessWidget {
  final _NavItem     item;
  final bool         active;
  final bool         showBadge;
  final Color        color;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.active,
    required this.showBadge,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration:   const Duration(milliseconds: 200),
                  curve:      Curves.easeInOut,
                  padding:    EdgeInsets.symmetric(
                    horizontal: active ? 16 : 0,
                    vertical:   4,
                  ),
                  decoration: active
                      ? BoxDecoration(
                          color:        color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        )
                      : null,
                  child: FaIcon(item.icon, size: 18, color: color),
                ),
                if (showBadge)
                  Positioned(
                    top:   -2,
                    right: -4,
                    child: Container(
                      width:  8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:  theme.colorScheme.error,
                        shape:  BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
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
