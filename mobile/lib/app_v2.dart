import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_v2_legacy.dart' as legacy;
import 'post_video_dialog.dart';

export 'app_v2_legacy.dart' hide SearchScreen, MyPostsScreen, ServiceCard;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  final cityController = TextEditingController();
  List<legacy.ServicePost> posts = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await legacy.OzirafApiClient.fetchPosts();
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

  List<legacy.ServicePost> get filtered {
    final q = searchController.text.trim().toLowerCase();
    final city = cityController.text.trim().toLowerCase();
    return posts.where((post) {
      final value = '${post.title} ${post.description} ${post.category}'.toLowerCase();
      return (q.isEmpty || value.contains(q)) &&
          (city.isEmpty || post.city.toLowerCase().contains(city));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Encuentra lo que necesitas cerca de ti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar servicio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cityController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined),
              labelText: 'Ciudad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            legacy.ErrorPanel(message: error!, onRetry: load)
          else if (filtered.isEmpty)
            const legacy.PlaceholderPanel(
              icon: Icons.search_off,
              title: 'Sin resultados',
              message: 'No hay publicaciones que coincidan con tu búsqueda.',
            )
          else
            ...filtered.map((post) => ServiceCard(post: post)),
        ],
      ),
    );
  }
}

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key, required this.token});

  final String token;

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  bool loading = true;
  String? error;
  List<legacy.ServicePost> posts = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await legacy.OzirafApiClient.fetchMyPosts(widget.token);
      if (!mounted) return;
      setState(() {
        posts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mis publicaciones',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Estas publicaciones pertenecen a tu cuenta.',
            style: TextStyle(color: legacy.OzirafColors.muted),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            legacy.ErrorPanel(message: error!, onRetry: load)
          else if (posts.isEmpty)
            const legacy.PlaceholderPanel(
              icon: Icons.add_business_outlined,
              title: 'Todavía no tienes anuncios',
              message: 'Cuando publiques un servicio aparecerá aquí.',
            )
          else
            ...posts.map((post) => ServiceCard(post: post, owned: true)),
        ],
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.post, this.owned = false});

  final legacy.ServicePost post;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final images = post.media.where((item) => item.isImage).toList();
    final videos = post.media.where((item) => item.isVideo).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderAvatar(
                  photo: post.providerPhoto,
                  name: post.providerName,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        post.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: legacy.OzirafColors.primaryStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (owned) const Chip(label: Text('Tu anuncio')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _PostImageCarousel(images: images),
              if (images.length > 1) ...[
                const SizedBox(height: 5),
                Text(
                  '${images.length} fotos • usa las flechas o desliza',
                  style: const TextStyle(
                    color: legacy.OzirafColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showPostVideoDialog(
                  context,
                  url: videos.first.url,
                  title: post.title,
                  providerName: post.providerName,
                  description: post.description,
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Ver video del trabajo'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(color: legacy.OzirafColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 17),
                const SizedBox(width: 4),
                Expanded(child: Text('${post.city}, ${post.state}')),
                Text(
                  post.price,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostImageCarousel extends StatefulWidget {
  const _PostImageCarousel({required this.images});

  final List<legacy.PostMediaItem> images;

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
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

  Future<void> previous() async {
    if (index <= 0 || !controller.hasClients) return;
    await controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> next() async {
    if (index >= widget.images.length - 1 || !controller.hasClients) return;
    await controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.images.length > 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, itemIndex) {
                return Image.network(
                  widget.images[itemIndex].url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: legacy.OzirafColors.surfaceSoft,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 42),
                  ),
                );
              },
            ),
            if (many && index > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrow(
                    icon: Icons.chevron_left,
                    tooltip: 'Foto anterior',
                    onPressed: previous,
                  ),
                ),
              ),
            if (many && index < widget.images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _CarouselArrow(
                    icon: Icons.chevron_right,
                    tooltip: 'Siguiente foto',
                    onPressed: next,
                  ),
                ),
              ),
            if (many)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.images.length,
                      (dotIndex) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: dotIndex == index ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: dotIndex == index ? Colors.white : Colors.white70,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: Colors.white,
        icon: Icon(icon, size: 30),
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({
    required this.photo,
    required this.name,
    required this.size,
  });

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
        gradient: LinearGradient(
          colors: [
            legacy.OzirafColors.logoPrimary,
            legacy.OzirafColors.logoAccent,
          ],
        ),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * .32,
        ),
      ),
    );

    if (photo.trim().isEmpty) return fallback;

    if (photo.startsWith('data:image/')) {
      try {
        final comma = photo.indexOf(',');
        if (comma < 0) return fallback;
        final bytes = base64Decode(photo.substring(comma + 1));
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      } catch (_) {
        return fallback;
      }
    }

    return ClipOval(
      child: Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'O';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
