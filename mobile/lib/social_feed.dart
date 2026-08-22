import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_v2.dart' as core;
import 'post_video_dialog.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final searchController = TextEditingController();
  List<core.ServicePost> posts = const [];
  bool loading = true;
  String? error;
  String selectedCategory = 'Todos';
  int topTab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await core.OzirafApiClient.fetchPosts();
      if (!mounted) return;
      setState(() {
        posts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        posts = const [];
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<String> get categories {
    final values = <String>{};
    for (final post in posts) {
      final value = post.category.trim();
      if (value.isNotEmpty) values.add(value);
      if (values.length >= 5) break;
    }
    return ['Todos', ...values];
  }

  List<core.ServicePost> get filtered {
    final query = searchController.text.trim().toLowerCase();
    return posts.where((post) {
      final haystack = '${post.title} ${post.description} ${post.category} ${post.city} ${post.state}'.toLowerCase();
      final queryOk = query.isEmpty || haystack.contains(query);
      final categoryOk = selectedCategory == 'Todos' || post.category == selectedCategory;
      return queryOk && categoryOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        final contentWidth = desktop ? 760.0 : 720.0;

        final feed = RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(desktop ? 0 : 14, 14, desktop ? 0 : 14, 110),
            children: [
              _TopTabs(
                selected: topTab,
                onChanged: (value) => setState(() => topTab = value),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '¿Qué servicio necesitas?',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Filtros',
                    onPressed: () {},
                    icon: const Icon(Icons.tune),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Color(0xFFE8EBF2)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == selectedCategory;
                    return ChoiceChip(
                      selected: selected,
                      avatar: Icon(_categoryIcon(category), size: 18),
                      label: Text(category),
                      onSelected: (_) => setState(() => selectedCategory = category),
                      side: BorderSide(color: selected ? Colors.transparent : const Color(0xFFE5E7EF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                core.ErrorPanel(message: error!, onRetry: load)
              else if (filtered.isEmpty)
                const core.PlaceholderPanel(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  message: 'Prueba con otro servicio o categoría.',
                )
              else
                ...filtered.map((post) => SocialServiceCard(post: post)),
            ],
          ),
        );

        if (!desktop) return feed;

        return ColoredBox(
          color: const Color(0xFFF7F8FC),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 26),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: contentWidth, child: feed),
                ),
              ),
              const SizedBox(width: 22),
              const SizedBox(
                width: 280,
                child: Padding(
                  padding: EdgeInsets.only(top: 18, right: 22),
                  child: _DesktopAside(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Servicios', 'Explorar', 'Cerca de ti'];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8EBF2)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == selected;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF0EDFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 2) ...[
                      Icon(Icons.location_on_outlined, size: 18, color: active ? const Color(0xFF654CFF) : null),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        labels[index],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: active ? const Color(0xFF654CFF) : const Color(0xFF272A35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SocialServiceCard extends StatelessWidget {
  const SocialServiceCard({super.key, required this.post});

  final core.ServicePost post;

  @override
  Widget build(BuildContext context) {
    final images = post.media.where((item) => item.isImage).toList();
    final videos = post.media.where((item) => item.isVideo).toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE8EAF1)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SocialAvatar(photo: post.providerPhoto, name: post.providerName, size: 50),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.verified, size: 17, color: Color(0xFF4285F4)),
                        ],
                      ),
                      Text(
                        post.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6D7280), fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF747987)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${post.city}, ${post.state}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF747987)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
              ],
            ),
            const SizedBox(height: 12),
            if (images.isNotEmpty)
              _SocialCarousel(images: images)
            else if (videos.isNotEmpty)
              _VideoPoster(post: post, video: videos.first)
            else
              _NoMediaPlaceholder(category: post.category),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        post.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF6D7280), height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Desde', style: TextStyle(fontSize: 11, color: Color(0xFF818695))),
                    Text(
                      post.price,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF654CFF)),
                    ),
                  ],
                ),
              ],
            ),
            if (images.isNotEmpty && videos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showPostVideoDialog(
                    context,
                    url: videos.first.url,
                    title: post.title,
                    providerName: post.providerName,
                    description: post.description,
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Ver video'),
                ),
              ),
            ],
            const Divider(height: 24),
            Wrap(
              spacing: 2,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionButton(icon: Icons.favorite_border, label: 'Me gusta', onTap: () => _toast(context, 'Me gusta')),
                _ActionButton(icon: Icons.chat_bubble_outline, label: 'Comentarios', onTap: () => _toast(context, 'Comentarios')),
                _ActionButton(icon: Icons.send_outlined, label: 'Compartir', onTap: () => _toast(context, 'Compartir')),
                _ActionButton(icon: Icons.bookmark_border, label: 'Guardar', onTap: () => _toast(context, 'Guardar')),
                FilledButton.icon(
                  onPressed: () => _toast(context, 'Contacto con ${post.providerName}'),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Contactar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF654CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialCarousel extends StatefulWidget {
  const _SocialCarousel({required this.images});

  final List<core.PostMediaItem> images;

  @override
  State<_SocialCarousel> createState() => _SocialCarouselState();
}

class _SocialCarouselState extends State<_SocialCarousel> {
  late final PageController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void go(int nextIndex) {
    if (!controller.hasClients || nextIndex < 0 || nextIndex >= widget.images.length) return;
    controller.animateToPage(nextIndex, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).width >= 700 ? 360.0 : 270.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (_, itemIndex) => Image.network(
                widget.images[itemIndex].url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFF0F2F7),
                  child: Center(child: Icon(Icons.broken_image_outlined, size: 42)),
                ),
              ),
            ),
            if (widget.images.length > 1 && index > 0)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(icon: Icons.chevron_left, onTap: () => go(index - 1))),
              ),
            if (widget.images.length > 1 && index < widget.images.length - 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(child: _Arrow(icon: Icons.chevron_right, onTap: () => go(index + 1))),
              ),
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (dot) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: dot == index ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: dot == index ? const Color(0xFF654CFF) : Colors.white70,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoPoster extends StatelessWidget {
  const _VideoPoster({required this.post, required this.video});

  final core.ServicePost post;
  final core.PostMediaItem video;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showPostVideoDialog(
        context,
        url: video.url,
        title: post.title,
        providerName: post.providerName,
        description: post.description,
      ),
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF25223A), Color(0xFF654CFF)]),
        ),
        child: const Center(
          child: CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Icon(Icons.play_arrow_rounded, size: 44, color: Color(0xFF25223A)),
          ),
        ),
      ),
    );
  }
}

class _NoMediaPlaceholder extends StatelessWidget {
  const _NoMediaPlaceholder({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF1EEFF), Color(0xFFEAF6FF)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Icon(_categoryIcon(category), size: 54, color: const Color(0xFF654CFF)),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .94),
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(onPressed: onTap, icon: Icon(icon, size: 30)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: const Color(0xFF343846)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF686D7A))),
          ],
        ),
      ),
    );
  }
}

class _SocialAvatar extends StatelessWidget {
  const _SocialAvatar({required this.photo, required this.name, required this.size});

  final String photo;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF8A3FFC), Color(0xFF2DB7FF)]),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .3),
      ),
    );

    Widget photoWidget = fallback;
    if (photo.startsWith('data:image/')) {
      try {
        final comma = photo.indexOf(',');
        if (comma >= 0) {
          photoWidget = Image.memory(
            base64Decode(photo.substring(comma + 1)),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      } catch (_) {}
    } else if (photo.trim().isNotEmpty) {
      photoWidget = Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF8A3FFC), Color(0xFFEF5DA8), Color(0xFFFFB648)]),
      ),
      child: ClipOval(child: photoWidget),
    );
  }
}

class _DesktopAside extends StatelessWidget {
  const _DesktopAside();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AsideCard(
          icon: Icons.add_business_outlined,
          title: 'Publica tu servicio',
          text: 'Llega a más personas y haz crecer tu negocio.',
          action: 'Publicar ahora',
        ),
        const SizedBox(height: 14),
        _AsideCard(
          icon: Icons.local_fire_department_outlined,
          title: 'Tendencias cerca de ti',
          text: 'Servicios populares y nuevas oportunidades en tu zona.',
          action: 'Explorar',
        ),
      ],
    );
  }
}

class _AsideCard extends StatelessWidget {
  const _AsideCard({required this.icon, required this.title, required this.text, required this.action});

  final IconData icon;
  final String title;
  final String text;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE8EAF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF654CFF), size: 30),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Color(0xFF6D7280), height: 1.35)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () {}, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(String value) {
  final text = value.toLowerCase();
  if (text.contains('yoga') || text.contains('bienestar')) return Icons.self_improvement_outlined;
  if (text.contains('electric')) return Icons.electrical_services_outlined;
  if (text.contains('constru') || text.contains('remodel')) return Icons.home_repair_service_outlined;
  if (text.contains('3d') || text.contains('impresi')) return Icons.view_in_ar_outlined;
  if (text.contains('limpieza')) return Icons.cleaning_services_outlined;
  if (text.contains('program') || text.contains('tecn')) return Icons.memory_outlined;
  if (value == 'Todos') return Icons.grid_view_rounded;
  return Icons.category_outlined;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
  if (parts.isEmpty) return 'O';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 1)));
}
