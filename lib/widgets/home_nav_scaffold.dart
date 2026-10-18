import 'package:flutter/material.dart';

/// One bottom-nav destination: its icon pair, label, and page. [page]
/// keeps its own Scaffold/AppBar — this widget only owns tab switching.
class NavTab {
  const NavTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;
  final int? badgeCount;
}

/// Shared bottom-navbar shell for both Host/AgentHomeScreen, replacing
/// the old HomeDrawer per docs/MOBILE-BOTTOM-NAVBAR.md. Every tab is
/// kept alive in an [IndexedStack] so switching tabs never re-triggers
/// a tab's initial load.
class HomeNavScaffold extends StatefulWidget {
  const HomeNavScaffold({super.key, required this.tabs});

  final List<NavTab> tabs;

  @override
  State<HomeNavScaffold> createState() => _HomeNavScaffoldState();
}

class _HomeNavScaffoldState extends State<HomeNavScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final tab in widget.tabs) tab.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: _badged(Icon(tab.icon), tab.badgeCount),
              selectedIcon: _badged(Icon(tab.selectedIcon), tab.badgeCount),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  Widget _badged(Widget icon, int? count) {
    final hasBadge = count != null && count > 0;
    return Badge(
      isLabelVisible: hasBadge,
      label: hasBadge ? Text('$count') : null,
      child: icon,
    );
  }
}
