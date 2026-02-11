import 'package:flutter/material.dart';

const _destinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.grid_view_outlined),
    selectedIcon: Icon(Icons.grid_view),
    label: 'Installations',
  ),
  NavigationDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: 'Today',
  ),
  NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: 'Schedules',
  ),
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];

const _railDestinations = <NavigationRailDestination>[
  NavigationRailDestination(
    icon: Icon(Icons.grid_view_outlined),
    selectedIcon: Icon(Icons.grid_view),
    label: Text('Installations'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.today_outlined),
    selectedIcon: Icon(Icons.today),
    label: Text('Today'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: Text('Schedules'),
  ),
  NavigationRailDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: Text('Settings'),
  ),
];

class GpBottomNavBar extends StatelessWidget {
  const GpBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: _destinations,
    );
  }
}

class GpRailNav extends StatelessWidget {
  const GpRailNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
    this.extended = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      extended: extended,
      labelType: extended ? null : NavigationRailLabelType.selected,
      groupAlignment: -0.85,
      useIndicator: true,
      destinations: _railDestinations,
    );
  }
}
