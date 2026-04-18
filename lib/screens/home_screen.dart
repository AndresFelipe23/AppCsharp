import 'package:flutter/material.dart';
import 'package:sliding_clipped_nav_bar/sliding_clipped_nav_bar.dart';
import '../theme/app_theme.dart';
import 'inicio_screen.dart';
import 'progreso_screen.dart';
import 'ejercicios_screen.dart';
import 'perfil_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const InicioScreen(),
    const ProgresoScreen(),
    const EjerciciosScreen(),
    const PerfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: SlidingClippedNavBar(
        backgroundColor: Colors.white,
        onButtonPressed: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        iconSize: 30,
        activeColor: AppTheme.primaryColor,
        selectedIndex: _selectedIndex,
        barItems: [
          BarItem(
            icon: Icons.home_outlined,
            title: 'Inicio',
          ),
          BarItem(
            icon: Icons.trending_up_outlined,
            title: 'Progreso',
          ),
          BarItem(
            icon: Icons.assignment_outlined,
            title: 'Ejercicios',
          ),
          BarItem(
            icon: Icons.person_outline,
            title: 'Perfil',
          ),
        ],
      ),
    );
  }
}
