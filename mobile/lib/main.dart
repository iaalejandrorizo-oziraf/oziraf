import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const OzirafApp());
}

class OzirafApp extends StatelessWidget {
  const OzirafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OZIRAF',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OzirafColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: OzirafColors.background,
        fontFamily: 'Arial',
      ),
      home: const HomeShell(),
    );
  }
}

class OzirafColors {
  static const background = Color(0xFFF8FBFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF1F7FF);
  static const border = Color(0xFFDCE4EE);
  static const text = Color(0xFF17212B);
  static const muted = Color(0xFF677282);
  static const primary = Color(0xFF4285F4);
  static const primaryStrong = Color(0xFF1A73E8);
  static const primarySoft = Color(0xFFE8F0FE);
  static const accent = Color(0xFF34A853);
  static const highlight = Color(0xFFFBBC05);
  static const danger = Color(0xFFEA4335);
  static const logoPrimary = Color(0xFF863BFF);
  static const logoStrong = Color(0xFF6417E8);
  static const logoAccent = Color(0xFF47BFFF);
}

enum AppTab { buscar, favoritos, solicitudes, publicar, cuenta }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab selectedTab = AppTab.buscar;
  String query = '';
  String city = '';
  String category = '';
  bool isLoadingPosts = true;
  String status = 'Conectando con OZIRAF';
  List<ServicePost> posts = demoPosts;

  List<ServicePost> get filteredPosts {
    return posts.where((post) {
      final fullText = '${post.title} ${post.description} ${post.category}'
          .toLowerCase();
      final matchesQuery =
          query.isEmpty || fullText.contains(query.toLowerCase());
      final matchesCity =
          city.isEmpty || post.city.toLowerCase().contains(city.toLowerCase());
      final matchesCategory =
          category.isEmpty ||
          post.category.toLowerCase().contains(category.toLowerCase());

      return matchesQuery && matchesCity && matchesCategory;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadPosts();
  }

  Future<void> loadPosts() async {
    setState(() {
      isLoadingPosts = true;
      status = 'Conectando con ${OzirafApiClient.baseUrl}';
    });

    try {
      final result = await OzirafApiClient.fetchPosts();

      if (!mounted) return;

      setState(() {
        posts = result.isEmpty ? demoPosts : result;
        status = result.isEmpty
            ? 'Backend conectado sin publicaciones'
            : 'Conectado a ${OzirafApiClient.baseUrl}';
        isLoadingPosts = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        posts = demoPosts;
        status = 'Modo demo: no conecta ${OzirafApiClient.baseUrl}';
        isLoadingPosts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  OzirafNavigationRail(
                    selectedTab: selectedTab,
                    onSelect: (tab) => setState(() => selectedTab = tab),
                  ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: AppHeader(
                          subtitle: isWide ? 'Web + movil' : 'App movil',
                          status: status,
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 28 : 16,
                          0,
                          isWide ? 28 : 16,
                          isWide ? 28 : 92,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _contentForTab(isWide),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isWide
              ? null
              : OzirafBottomNavigation(
                  selectedTab: selectedTab,
                  onSelect: (tab) => setState(() => selectedTab = tab),
                ),
        );
      },
    );
  }

  Widget _contentForTab(bool isWide) {
    switch (selectedTab) {
      case AppTab.buscar:
        return SearchScreen(
          key: const ValueKey('buscar'),
          isWide: isWide,
          posts: filteredPosts,
          isLoading: isLoadingPosts,
          status: status,
          query: query,
          city: city,
          category: category,
          onQueryChanged: (value) => setState(() => query = value),
          onCityChanged: (value) => setState(() => city = value),
          onCategoryChanged: (value) => setState(() => category = value),
          onRefresh: loadPosts,
        );
      case AppTab.favoritos:
        return PlaceholderPanel(
          key: const ValueKey('favoritos'),
          icon: Icons.favorite_border,
          title: 'Favoritos',
          message: 'Aqui apareceran los servicios guardados desde tu cuenta.',
        );
      case AppTab.solicitudes:
        return PlaceholderPanel(
          key: const ValueKey('solicitudes'),
          icon: Icons.chat_bubble_outline,
          title: 'Mis solicitudes',
          message: 'Da seguimiento a los mensajes enviados a proveedores.',
        );
      case AppTab.publicar:
        return PlaceholderPanel(
          key: const ValueKey('publicar'),
          icon: Icons.add_business_outlined,
          title: 'Publicar servicio',
          message: 'El siguiente bloque conectara alta de servicios y fotos.',
        );
      case AppTab.cuenta:
        return AccountScreen(key: const ValueKey('cuenta'));
    }
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.subtitle, required this.status});

  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          const OzirafMark(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OZIRAF',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: OzirafColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: OzirafColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: OzirafColors.surface,
              border: Border.all(color: OzirafColors.border),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'OZIRAF',
              style: TextStyle(
                color: OzirafColors.primaryStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OzirafMark extends StatelessWidget {
  const OzirafMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OzirafColors.logoPrimary, OzirafColors.logoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Container(
          width: size * 0.36,
          height: size * 0.36,
          decoration: BoxDecoration(
            color: OzirafColors.surface,
            borderRadius: BorderRadius.circular(size * 0.12),
          ),
        ),
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.isWide,
    required this.posts,
    required this.isLoading,
    required this.status,
    required this.query,
    required this.city,
    required this.category,
    required this.onQueryChanged,
    required this.onCityChanged,
    required this.onCategoryChanged,
    required this.onRefresh,
  });

  final bool isWide;
  final List<ServicePost> posts;
  final bool isLoading;
  final String status;
  final String query;
  final String city;
  final String category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onCategoryChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encuentra profesionales confiables cerca de ti',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: OzirafColors.text,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 18),
        FilterPanel(
          isWide: isWide,
          query: query,
          city: city,
          category: category,
          onQueryChanged: onQueryChanged,
          onCityChanged: onCityChanged,
          onCategoryChanged: onCategoryChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                isLoading
                    ? 'Cargando servicios...'
                    : '${posts.length} servicios disponibles',
                style: const TextStyle(
                  color: OzirafColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              color: OzirafColors.primaryStrong,
            ),
          ],
        ),
        Text(
          status,
          style: const TextStyle(color: OzirafColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else if (posts.isEmpty)
          const PlaceholderPanel(
            icon: Icons.search_off,
            title: 'No hay servicios',
            message: 'Ajusta los filtros o vuelve a actualizar.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 2 : 1,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: isWide ? 282 : 318,
            ),
            itemBuilder: (context, index) => ServiceCard(
              post: posts[index],
              onTap: () => showServiceDetails(context, posts[index], isWide),
            ),
          ),
      ],
    );
  }
}

class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    required this.isWide,
    required this.query,
    required this.city,
    required this.category,
    required this.onQueryChanged,
    required this.onCityChanged,
    required this.onCategoryChanged,
  });

  final bool isWide;
  final String query;
  final String city;
  final String category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final fields = [
      OzirafTextField(
        icon: Icons.search,
        hint: 'Buscar servicio',
        value: query,
        onChanged: onQueryChanged,
      ),
      OzirafTextField(
        icon: Icons.location_on_outlined,
        hint: 'Ciudad',
        value: city,
        onChanged: onCityChanged,
      ),
      OzirafTextField(
        icon: Icons.tune,
        hint: 'Categoria',
        value: category,
        onChanged: onCategoryChanged,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OzirafColors.surface,
        border: Border.all(color: OzirafColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: isWide
          ? Row(
              children: fields
                  .map(
                    (field) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: field,
                      ),
                    ),
                  )
                  .toList(),
            )
          : Column(
              children: fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: field,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class OzirafTextField extends StatelessWidget {
  const OzirafTextField({
    super.key,
    required this.icon,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: OzirafColors.muted),
        hintText: hint,
        filled: true,
        fillColor: OzirafColors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OzirafColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OzirafColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OzirafColors.primary, width: 2),
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.post, required this.onTap});

  final ServicePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: OzirafColors.surface,
              border: Border.all(color: OzirafColors.border),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceImageBanner(post: post, height: 118),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: OzirafTag(label: post.category)),
                          const SizedBox(width: 8),
                          RatingBadge(post: post),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        post.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OzirafColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OzirafColors.muted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: OzirafColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.locationLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: OzirafColors.muted),
                            ),
                          ),
                          Text(
                            post.price,
                            style: const TextStyle(
                              color: OzirafColors.accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
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

class ServiceImageBanner extends StatelessWidget {
  const ServiceImageBanner({
    super.key,
    required this.post,
    required this.height,
  });

  final ServicePost post;
  final double height;

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrls.isEmpty ? null : post.imageUrls.first;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: imageUrl == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: post.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(post.icon, color: OzirafColors.surface, size: 42),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: post.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(post.icon, color: OzirafColors.surface, size: 42),
                ),
              ),
            ),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.post});

  final ServicePost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: OzirafColors.surfaceSoft,
        border: Border.all(color: OzirafColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: OzirafColors.primaryStrong),
          const SizedBox(width: 4),
          Text(
            post.ratingLabel,
            style: const TextStyle(
              color: OzirafColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showServiceDetails(
  BuildContext context,
  ServicePost post,
  bool isWide,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ServiceDetailSheet(post: post, isWide: isWide),
  );
}

class ServiceDetailSheet extends StatelessWidget {
  const ServiceDetailSheet({
    super.key,
    required this.post,
    required this.isWide,
  });

  final ServicePost post;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: isWide ? 0.78 : 0.88,
      maxChildSize: 0.94,
      minChildSize: 0.45,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: OzirafColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: OzirafColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ServiceImageBanner(post: post, height: isWide ? 260 : 190),
            ),
            if (post.imageUrls.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.imageUrls.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.imageUrls[index],
                      width: 92,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OzirafTag(label: post.category)),
                const SizedBox(width: 8),
                RatingBadge(post: post),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: OzirafColors.text,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.providerName,
              style: const TextStyle(
                color: OzirafColors.primaryStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            InfoLine(icon: Icons.location_on_outlined, text: post.fullLocation),
            InfoLine(icon: Icons.payments_outlined, text: post.price),
            if (post.phone.isNotEmpty)
              InfoLine(icon: Icons.phone_outlined, text: post.phone),
            if (post.whatsapp.isNotEmpty)
              InfoLine(icon: Icons.chat_outlined, text: post.whatsapp),
            const SizedBox(height: 14),
            Text(
              post.description,
              style: const TextStyle(
                color: OzirafColors.text,
                height: 1.45,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ContactAction(
                  icon: Icons.phone_outlined,
                  label: 'Llamar',
                  onPressed: () => openPhone(context, post.phone),
                ),
                ContactAction(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  onPressed: () => openWhatsapp(context, post.whatsapp),
                ),
                ContactAction(
                  icon: Icons.favorite_border,
                  label: 'Guardar',
                  onPressed: () => showOzirafMessage(
                    context,
                    'Favoritos se conectara con tu cuenta en el siguiente bloque.',
                  ),
                ),
                if (post.websiteUrl.isNotEmpty)
                  ContactAction(
                    icon: Icons.language,
                    label: 'Web',
                    onPressed: () => openExternalLink(context, post.websiteUrl),
                  ),
                if (post.instagramUrl.isNotEmpty)
                  ContactAction(
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram',
                    onPressed: () =>
                        openExternalLink(context, post.instagramUrl),
                  ),
                if (post.facebookUrl.isNotEmpty)
                  ContactAction(
                    icon: Icons.groups_outlined,
                    label: 'Facebook',
                    onPressed: () =>
                        openExternalLink(context, post.facebookUrl),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: OzirafColors.muted, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: OzirafColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContactAction extends StatelessWidget {
  const ContactAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: OzirafColors.accent,
        foregroundColor: OzirafColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class OzirafTag extends StatelessWidget {
  const OzirafTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: OzirafColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: OzirafColors.primaryStrong,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: OzirafColors.surface,
        border: Border.all(color: OzirafColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: OzirafColors.primary, size: 34),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: OzirafColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  bool isSubmitting = false;
  String? accountMessage;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    cityController.dispose();
    stateController.dispose();
    super.dispose();
  }

  Future<void> submitRegister() async {
    if (!formKey.currentState!.validate() || isSubmitting) return;

    setState(() {
      isSubmitting = true;
      accountMessage = null;
    });

    try {
      final user = await OzirafApiClient.register(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        email: emailController.text,
        password: passwordController.text,
        phone: phoneController.text,
        city: cityController.text,
        state: stateController.text,
      );

      if (!mounted) return;

      setState(() {
        accountMessage =
            'Cuenta creada: ${valueAsString(user['email'], fallback: emailController.text)}';
        passwordController.clear();
        isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        accountMessage = error.toString().replaceFirst('Exception: ', '');
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OzirafColors.surface,
        border: Border.all(color: OzirafColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crear cuenta',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: OzirafColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Registra un cliente o proveedor para probar OZIRAF desde el celular.',
              style: TextStyle(color: OzirafColors.muted, height: 1.35),
            ),
            const SizedBox(height: 18),
            AccountTextField(
              controller: firstNameController,
              icon: Icons.person_outline,
              label: 'Nombre',
              validator: requiredValidator,
            ),
            AccountTextField(
              controller: lastNameController,
              icon: Icons.badge_outlined,
              label: 'Apellido',
            ),
            AccountTextField(
              controller: emailController,
              icon: Icons.email_outlined,
              label: 'Correo',
              keyboardType: TextInputType.emailAddress,
              validator: emailValidator,
            ),
            AccountTextField(
              controller: passwordController,
              icon: Icons.lock_outline,
              label: 'Contraseña',
              obscureText: true,
              validator: passwordValidator,
            ),
            AccountTextField(
              controller: phoneController,
              icon: Icons.phone_outlined,
              label: 'Telefono / WhatsApp',
              keyboardType: TextInputType.phone,
            ),
            Row(
              children: [
                Expanded(
                  child: AccountTextField(
                    controller: cityController,
                    icon: Icons.location_city_outlined,
                    label: 'Ciudad',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AccountTextField(
                    controller: stateController,
                    icon: Icons.map_outlined,
                    label: 'Estado',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSubmitting ? null : submitRegister,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(
                  isSubmitting ? 'Creando cuenta...' : 'Crear cuenta',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: OzirafColors.primaryStrong,
                  foregroundColor: OzirafColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (accountMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                accountMessage!,
                style: TextStyle(
                  color: accountMessage!.startsWith('Cuenta creada')
                      ? OzirafColors.accent
                      : OzirafColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AccountTextField extends StatelessWidget {
  const AccountTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: OzirafColors.muted),
          labelText: label,
          filled: true,
          fillColor: OzirafColors.surfaceSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: OzirafColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: OzirafColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: OzirafColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class OzirafNavigationRail extends StatelessWidget {
  const OzirafNavigationRail({
    super.key,
    required this.selectedTab,
    required this.onSelect,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: OzirafColors.surface,
        border: Border(right: BorderSide(color: OzirafColors.border)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              OzirafMark(size: 42),
              SizedBox(width: 10),
              Text(
                'OZIRAF',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 28),
          ...AppTab.values.map(
            (tab) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NavButton(
                tab: tab,
                selected: selectedTab == tab,
                onTap: () => onSelect(tab),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OzirafBottomNavigation extends StatelessWidget {
  const OzirafBottomNavigation({
    super.key,
    required this.selectedTab,
    required this.onSelect,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(
            color: OzirafColors.surface,
            border: Border(top: BorderSide(color: OzirafColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: AppTab.values
                .map(
                  (tab) => Expanded(
                    child: Center(
                      child: NavButton(
                        tab: tab,
                        selected: selectedTab == tab,
                        compact: true,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  const NavButton({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = selected ? OzirafColors.primaryStrong : OzirafColors.muted;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: compact ? 68 : null,
        height: compact ? 58 : null,
        constraints: BoxConstraints(minHeight: compact ? 58 : 48),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 12,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          color: selected ? OzirafColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab.icon, color: color, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(tab.icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    tab.label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
      ),
    );
  }
}

extension AppTabMeta on AppTab {
  String get label {
    switch (this) {
      case AppTab.buscar:
        return 'Buscar';
      case AppTab.favoritos:
        return 'Favoritos';
      case AppTab.solicitudes:
        return 'Solicitudes';
      case AppTab.publicar:
        return 'Publicar';
      case AppTab.cuenta:
        return 'Cuenta';
    }
  }

  IconData get icon {
    switch (this) {
      case AppTab.buscar:
        return Icons.search;
      case AppTab.favoritos:
        return Icons.favorite_border;
      case AppTab.solicitudes:
        return Icons.chat_bubble_outline;
      case AppTab.publicar:
        return Icons.add_circle_outline;
      case AppTab.cuenta:
        return Icons.person_outline;
    }
  }
}

class ServicePost {
  const ServicePost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.city,
    required this.state,
    required this.price,
    required this.icon,
    required this.colors,
    required this.neighborhood,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.instagramUrl,
    required this.facebookUrl,
    required this.websiteUrl,
    required this.imageUrls,
    required this.averageRating,
    required this.reviewCount,
    required this.providerName,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String city;
  final String state;
  final String price;
  final IconData icon;
  final List<Color> colors;
  final String neighborhood;
  final String address;
  final String phone;
  final String whatsapp;
  final String instagramUrl;
  final String facebookUrl;
  final String websiteUrl;
  final List<String> imageUrls;
  final double? averageRating;
  final int reviewCount;
  final String providerName;

  String get locationLabel {
    final parts = [if (neighborhood.isNotEmpty) neighborhood, city, state];

    return parts.where((part) => part.trim().isNotEmpty).join(', ');
  }

  String get fullLocation {
    final parts = [
      if (address.isNotEmpty) address,
      if (neighborhood.isNotEmpty) neighborhood,
      city,
      state,
    ];

    return parts.where((part) => part.trim().isNotEmpty).join(', ');
  }

  String get ratingLabel {
    if (averageRating == null || reviewCount == 0) return 'Nuevo';
    return '${averageRating!.toStringAsFixed(1)} ($reviewCount)';
  }

  factory ServicePost.fromJson(Map<String, dynamic> json) {
    final category = valueAsString(json['category'], fallback: 'Servicio');
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final firstName = valueAsString(user['firstName'], fallback: '');
    final lastName = valueAsString(user['lastName'], fallback: '');
    final providerName = '$firstName $lastName'.trim();

    return ServicePost(
      id: valueAsString(json['id'], fallback: json.hashCode.toString()),
      title: valueAsString(json['title'], fallback: 'Servicio local'),
      description: valueAsString(
        json['description'],
        fallback: 'Servicio disponible en OZIRAF.',
      ),
      category: category,
      city: valueAsString(json['city'], fallback: 'Ciudad'),
      state: valueAsString(json['state'], fallback: 'Estado'),
      price: formatPrice(json['price']),
      icon: iconForCategory(category),
      colors: colorsForCategory(category),
      neighborhood: valueAsString(json['neighborhood'], fallback: ''),
      address: valueAsString(json['address'], fallback: ''),
      phone: valueAsString(user['phone'], fallback: ''),
      whatsapp: valueAsString(user['whatsapp'], fallback: ''),
      instagramUrl: valueAsString(user['instagramUrl'], fallback: ''),
      facebookUrl: valueAsString(user['facebookUrl'], fallback: ''),
      websiteUrl: valueAsString(user['websiteUrl'], fallback: ''),
      imageUrls: stringListFromJson(json['imageUrls']),
      averageRating: doubleFromJson(json['averageRating']),
      reviewCount: intFromJson(json['reviewCount']),
      providerName: providerName.isEmpty ? 'Proveedor OZIRAF' : providerName,
    );
  }
}

const demoPosts = [
  ServicePost(
    id: 'demo-1',
    title: 'Remodelacion integral de vivienda',
    description: 'Diseno, presupuesto y ejecucion para casas y departamentos.',
    category: 'Construccion',
    city: 'Guadalajara',
    state: 'Jalisco',
    price: '\$2,500',
    icon: Icons.home_repair_service_outlined,
    colors: [OzirafColors.primary, OzirafColors.accent],
    neighborhood: 'Providencia',
    address: 'Zona metropolitana',
    phone: '+52 33 1000 2000',
    whatsapp: '+52 33 1000 2000',
    instagramUrl: '@oziraf_remodela',
    facebookUrl: '',
    websiteUrl: 'oziraf.local',
    imageUrls: [],
    averageRating: 4.8,
    reviewCount: 24,
    providerName: 'Mariana Torres',
  ),
  ServicePost(
    id: 'demo-2',
    title: 'Electricista certificado para hogar',
    description: 'Instalaciones, reparaciones y revision de cargas electricas.',
    category: 'Tecnicos',
    city: 'Zapopan',
    state: 'Jalisco',
    price: '\$650',
    icon: Icons.electrical_services_outlined,
    colors: [OzirafColors.highlight, OzirafColors.danger],
    neighborhood: 'Centro',
    address: 'Servicio a domicilio',
    phone: '+52 33 2000 3000',
    whatsapp: '+52 33 2000 3000',
    instagramUrl: '',
    facebookUrl: 'Electricistas OZIRAF',
    websiteUrl: '',
    imageUrls: [],
    averageRating: 4.6,
    reviewCount: 18,
    providerName: 'Carlos Mendez',
  ),
  ServicePost(
    id: 'demo-3',
    title: 'Limpieza profunda para mudanza',
    description: 'Equipo de limpieza para casas, oficinas y departamentos.',
    category: 'Limpieza',
    city: 'Monterrey',
    state: 'Nuevo Leon',
    price: '\$1,200',
    icon: Icons.cleaning_services_outlined,
    colors: [OzirafColors.accent, OzirafColors.primary],
    neighborhood: 'Centro',
    address: 'Cobertura local',
    phone: '+52 81 3000 4000',
    whatsapp: '+52 81 3000 4000',
    instagramUrl: '@limpieza.oziraf',
    facebookUrl: '',
    websiteUrl: '',
    imageUrls: [],
    averageRating: 4.9,
    reviewCount: 31,
    providerName: 'Sofia Ramos',
  ),
];

class OzirafApiClient {
  static const webBaseUrl = String.fromEnvironment(
    'OZIRAF_API_URL',
    defaultValue: 'http://localhost:3001',
  );
  static const androidBaseUrl = String.fromEnvironment(
    'OZIRAF_ANDROID_API_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static Future<List<ServicePost>> fetchPosts() async {
    final uri = Uri.parse('$baseUrl/posts?page=1&limit=20');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OZIRAF API ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];

    if (data is! List) return [];

    return data
        .whereType<Map<String, dynamic>>()
        .map(ServicePost.fromJson)
        .toList();
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String city,
    required String state,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final body = removeEmptyValues({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
      'whatsapp': phone.trim(),
      'city': city.trim(),
      'state': state.trim(),
    });

    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    final payload = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(errorMessageFromPayload(payload));
    }

    if (payload is Map<String, dynamic>) return payload;

    throw Exception('Respuesta inesperada del backend');
  }

  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidBaseUrl;
    }
    return webBaseUrl;
  }
}

String valueAsString(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

Map<String, dynamic> removeEmptyValues(Map<String, String> value) {
  return Map.fromEntries(
    value.entries.where((entry) => entry.value.trim().isNotEmpty),
  );
}

String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo requerido';
  return null;
}

String? emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Campo requerido';
  if (!text.contains('@') || !text.contains('.')) return 'Correo invalido';
  return null;
}

String? passwordValidator(String? value) {
  final text = value ?? '';
  if (text.length < 8) return 'Minimo 8 caracteres';
  return null;
}

String errorMessageFromPayload(Object? payload) {
  if (payload is Map<String, dynamic>) {
    final message = payload['message'];
    if (message is String) return message;
    if (message is List) return message.join(', ');
  }

  return 'No se pudo completar la solicitud';
}

List<String> stringListFromJson(Object? value) {
  if (value is! List) return const [];

  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

double? doubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Future<void> openPhone(BuildContext context, String phone) async {
  final normalized = digitsAndPlus(phone);

  if (normalized.isEmpty) {
    showOzirafMessage(context, 'Este proveedor aun no tiene telefono.');
    return;
  }

  await openUri(context, Uri(scheme: 'tel', path: normalized));
}

Future<void> openWhatsapp(BuildContext context, String phone) async {
  final normalized = digitsOnly(phone);

  if (normalized.isEmpty) {
    showOzirafMessage(context, 'Este proveedor aun no tiene WhatsApp.');
    return;
  }

  await openUri(context, Uri.parse('https://wa.me/$normalized'));
}

Future<void> openExternalLink(BuildContext context, String value) async {
  final uri = normalizeExternalUri(value);

  if (uri == null) {
    showOzirafMessage(context, 'Este enlace no esta disponible.');
    return;
  }

  await openUri(context, uri);
}

Future<void> openUri(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!opened && context.mounted) {
    showOzirafMessage(context, 'No se pudo abrir esta accion.');
  }
}

Uri? normalizeExternalUri(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('@')) {
    return Uri.parse('https://instagram.com/${trimmed.substring(1)}');
  }

  final hasScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://');
  final normalized = hasScheme ? trimmed : 'https://$trimmed';

  return Uri.tryParse(normalized);
}

String digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String digitsAndPlus(String value) {
  return value.replaceAll(RegExp(r'[^0-9+]'), '');
}

void showOzirafMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String formatPrice(Object? value) {
  if (value is num && value > 0) {
    return '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  }

  return 'Cotizar';
}

IconData iconForCategory(String category) {
  final normalized = category.toLowerCase();

  if (normalized.contains('limpieza')) return Icons.cleaning_services_outlined;
  if (normalized.contains('tecnico') || normalized.contains('electric')) {
    return Icons.electrical_services_outlined;
  }
  if (normalized.contains('constru') || normalized.contains('remodel')) {
    return Icons.home_repair_service_outlined;
  }
  if (normalized.contains('clase')) return Icons.school_outlined;

  return Icons.handyman_outlined;
}

List<Color> colorsForCategory(String category) {
  final normalized = category.toLowerCase();

  if (normalized.contains('limpieza')) {
    return const [OzirafColors.accent, OzirafColors.primary];
  }
  if (normalized.contains('clase')) {
    return const [OzirafColors.primary, OzirafColors.accent];
  }
  if (normalized.contains('tecnico') || normalized.contains('electric')) {
    return const [OzirafColors.highlight, OzirafColors.danger];
  }
  if (normalized.contains('constru') || normalized.contains('remodel')) {
    return const [OzirafColors.primary, OzirafColors.highlight];
  }

  return const [OzirafColors.primary, OzirafColors.accent];
}
