import 'package:flutter/material.dart';
import 'package:full_jizhang/theme.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return GlassBackground(
      child: AppFrame(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  MediaQuery.paddingOf(context).top + 8,
                  10,
                  bottom + 102,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.sheet,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sheet),
                      bottom: Radius.circular(AppRadius.sheet),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.sheet),
                      bottom: Radius.circular(AppRadius.sheet),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: bottom + 10,
              child: IconDock(
                location: location,
                onSelect: (path) => context.go(path),
                onRecord: () => context.push('/record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IconDock extends StatelessWidget {
  const IconDock({
    super.key,
    required this.location,
    required this.onSelect,
    required this.onRecord,
  });

  final String location;
  final ValueChanged<String> onSelect;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: AppColors.sheet,
              elevation: 12,
              shadowColor: const Color(0x22000000),
              shape: const _DockNotchBorder(),
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 78),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final item in _items)
                        _NavButton(
                          item: item,
                          selected: _selected(location, item.path),
                          onTap: () => onSelect(item.path),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 28,
            child: _RecordFab(onPressed: onRecord),
          ),
        ],
      ),
    );
  }
}

bool _selected(String location, String path) {
  if (path == '/') return location == '/';
  return location == path || location.startsWith('$path/');
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.sageDark : AppColors.faint;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          key: item.navKey,
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 26,
                ),
                if (selected)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.sage,
                      shape: BoxShape.circle,
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

class _RecordFab extends StatelessWidget {
  const _RecordFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '記一筆',
      child: Tooltip(
        message: '記一筆',
        child: Material(
          key: const Key('fab-record'),
          color: AppColors.sage,
          elevation: 8,
          shadowColor: AppColors.sageDark.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.navKey,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Key navKey;
}

const _ledger = _NavItem(
  path: '/',
  label: '帳本',
  icon: Icons.menu_book_outlined,
  selectedIcon: Icons.menu_book_rounded,
  navKey: Key('nav-ledger'),
);
const _analytics = _NavItem(
  path: '/analytics',
  label: '分析圖',
  icon: Icons.pie_chart_outline_rounded,
  selectedIcon: Icons.pie_chart_rounded,
  navKey: Key('nav-analytics'),
);
const _assets = _NavItem(
  path: '/assets',
  label: '資產',
  icon: Icons.account_balance_wallet_outlined,
  selectedIcon: Icons.account_balance_wallet,
  navKey: Key('nav-assets'),
);
const _settings = _NavItem(
  path: '/settings',
  label: '設定',
  icon: Icons.person_outline_rounded,
  selectedIcon: Icons.person_rounded,
  navKey: Key('nav-settings'),
);

const _items = [_ledger, _analytics, _assets, _settings];

/// Pill dock with a circular notch on the top-right for the record button.
class _DockNotchBorder extends ShapeBorder {
  const _DockNotchBorder();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final base = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      );
    final notch = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right - 36, rect.top + 8),
          radius: 30,
        ),
      );
    return Path.combine(PathOperation.difference, base, notch);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
