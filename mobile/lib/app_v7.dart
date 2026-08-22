import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'app_v6.dart' as base;
import 'social_feed.dart';

class OzirafApp extends base.OzirafApp {
  const OzirafApp({super.key});

  @override
  Widget build(BuildContext context) {
    final inherited = super.build(context);
    if (inherited is! MaterialApp) return inherited;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: inherited.title,
      theme: _socialTheme(inherited.theme),
      darkTheme: inherited.darkTheme,
      themeMode: inherited.themeMode,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      home: _SocialShell(legacyHome: inherited.home ?? const SizedBox.shrink()),
    );
  }
}

ThemeData _socialTheme(ThemeData? inherited) {
  final baseTheme = inherited ?? ThemeData(useMaterial3: true);
  return baseTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    cardTheme: const CardThemeData(color: Colors.white),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFEDE9FF),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? const Color(0xFF654CFF) : const Color(0xFF656A78),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? const Color(0xFF654CFF) : const Color(0xFF555B69));
      }),
    ),
  );
}

class _SocialShell extends StatefulWidget {
  const _SocialShell({required this.legacyHome});

  final Widget legacyHome;

  @override
  State<_SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<_SocialShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;

    if (desktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: Row(
          children: [
            _DesktopNav(
              selected: index,
              onSelected: (value) => setState(() => index = value),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE7E9F0)),
            Expanded(child: _body()),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: index == 0
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              titleSpacing: 16,
              title: const _BrandHeader(),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
                Stack(
                  children: [
                    IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                    const Positioned(
                      right: 11,
                      top: 11,
                      child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFEA4335)),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Publicar'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Mensajes'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
    );
  }

  Widget _body() {
    if (index == 0) return const SocialFeedScreen();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFFF0EDFF),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            _sectionMessage(index),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF513BD4), fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        Expanded(child: widget.legacyHome),
      ],
    );
  }

  String _sectionMessage(int value) => switch (value) {
        1 => 'Explorar: esta sección conservará sus funciones mientras recibe el nuevo diseño.',
        2 => 'Publicar: conservamos el formulario y carga de fotos/video que ya funcionan.',
        3 => 'Mensajes: esta sección será el siguiente bloque del rediseño social.',
        4 => 'Cuenta: tu sesión, perfil y datos permanecen intactos.',
        _ => '',
      };
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF45B8FF)]),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'OZIRAF',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.5, color: Color(0xFF1D2130)),
        ),
      ],
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Inicio'),
      (Icons.explore_outlined, 'Explorar'),
      (Icons.add_circle_outline, 'Publicar'),
      (Icons.chat_bubble_outline, 'Mensajes'),
      (Icons.bookmark_border, 'Guardados'),
      (Icons.person_outline, 'Cuenta'),
    ];

    return Container(
      width: 210,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: _BrandHeader()),
          const SizedBox(height: 30),
          ...List.generate(items.length, (itemIndex) {
            final shellIndex = itemIndex <= 3 ? itemIndex : itemIndex == 5 ? 4 : 1;
            final active = shellIndex == selected && itemIndex != 4;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                selected: active,
                selectedTileColor: const Color(0xFFF0EDFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(items[itemIndex].$1, color: active ? const Color(0xFF654CFF) : const Color(0xFF555B69)),
                title: Text(
                  items[itemIndex].$2,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? const Color(0xFF654CFF) : const Color(0xFF343846),
                  ),
                ),
                onTap: () => onSelected(shellIndex),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF4F1FF), Color(0xFFEEF8FF)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Eres profesional?', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Publica tus servicios y conecta con nuevos clientes.', style: TextStyle(fontSize: 12, color: Color(0xFF6D7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
