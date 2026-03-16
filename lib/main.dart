import 'package:flutter/material.dart';
import 'package:galaxy_way_customer/screens/new_delivery_scren.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

void main() => runApp(const GalaxyWayApp());

class GalaxyWayApp extends StatelessWidget {
  const GalaxyWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const NewDeliveryScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            // Cor dos ícones quando selecionados
            selectedIconTheme: const IconThemeData(color: Colors.indigo),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.store_outlined),
                // Ícone de loja vazada
                selectedIcon: Icon(Icons.store),
                // Ícone de loja preenchida ao clicar
                label: Text('Minha Loja'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_location_alt_outlined),
                selectedIcon: Icon(Icons.add_location_alt),
                label: Text('Novo Pedido'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Histórico'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
  }
}
