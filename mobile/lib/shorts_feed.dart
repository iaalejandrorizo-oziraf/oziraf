import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_v2.dart' as core;
import 'post_video_dialog.dart';
import 'video_source.dart';

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  List<_ShortItem> items = const [];
  bool loading = true;
  String? error;
  int currentIndex = 0;

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
      final posts = await core.OzirafApiClient.fetchPosts();
      final result = <_ShortItem>[];
      for (final post in posts) {
        for (final media in post.media.where((item) => item.isVideo)) {
          result.add(_ShortItem(post: post, media: media));
        }
      }
      if (!mounted) return;
      setState(() {
        items = result;
        loading = false;
        currentIndex = 0;
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
    if (loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white70, size: 46),
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 14),
                FilledButton.tonal(onPressed: load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.video_library_outlined, color: Colors.white70, size: 52),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay Shorts publicados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: items.length,
        onPageChanged: (value) => setState(() => currentIndex = value),
        itemBuilder: (context, index) {
          return _ShortVideoPage(
            key: ValueKey('${items[index].post.id}-${items[index].media.id}'),
            item: items[index],
            active: index == currentIndex,
          );
        },
      ),
    );
  }
}

class _ShortItem {
  const _ShortItem({required this.post, required this.media});

  final core.ServicePost post;
  final core.PostMediaItem media;
}

class _ShortVideoPage extends StatefulWidget {
  const _ShortVideoPage({
    super.key,
    required this.item,
    required this.active,
  });

  final _ShortItem item;
  final bool active;

  @override
  State<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<_ShortVideoPage> {
  VideoPlayerController? controller;
  bool initializing = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void didUpdateWidget(covariant _ShortVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        controller?.play();
      } else {
        controller?.pause();
      }
    }
  }

  Future<void> initialize() async {
    try {
      final next = await prepareVideoController(widget.item.media.url);
      await next.initialize();
      await next.setLooping(true);
      if (!mounted) {
        await next.dispose();
        return;
      }
      controller = next;
      if (widget.active) await next.play();
      setState(() => initializing = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        initializing = false;
        failed = true;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlayback() {
    final value = controller?.value;
    if (value == null || !value.isInitialized) return;
    value.isPlaying ? controller?.pause() : controller?.play();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.item.post;
    final player = controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: togglePlayback,
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: failed
                  ? const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 58)
                  : initializing || player == null || !player.value.isInitialized
                      ? const CircularProgressIndicator(color: Colors.white)
                      : FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: player.value.size.width,
                            height: player.value.size.height,
                            child: VideoPlayer(player),
                          ),
                        ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black26, Colors.transparent, Colors.transparent, Colors.black87],
                stops: [0, .2, .58, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 14,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Text(
                  'Shorts',
                  style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Buscar Shorts',
                  onPressed: () {},
                  style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 104,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShortAvatar(name: post.providerName),
                const SizedBox(height: 16),
                _ShortAction(icon: Icons.favorite_border, label: 'Me gusta', onPressed: () => _message(context, 'Me gusta')),
                const SizedBox(height: 14),
                _ShortAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comentar',
                  onPressed: () => _openFullPlayer(context),
                ),
                const SizedBox(height: 14),
                _ShortAction(icon: Icons.send_outlined, label: 'Compartir', onPressed: () => _openFullPlayer(context)),
                const SizedBox(height: 14),
                _ShortAction(icon: Icons.bookmark_border, label: 'Guardar', onPressed: () => _openFullPlayer(context)),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 82,
          bottom: 92,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          shadows: [Shadow(color: Colors.black, blurRadius: 5)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.verified, size: 17, color: Color(0xFF6DA7FF)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${post.category} • ${post.city}, ${post.state}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  post.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.3),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF654CFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        post.price,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _message(context, 'Contactar a ${post.providerName}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF252232),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Contactar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (player != null && player.value.isInitialized)
          Positioned(
            left: 10,
            right: 10,
            bottom: 4,
            child: SafeArea(
              top: false,
              child: VideoProgressIndicator(
                player,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 7),
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF7C5CFF),
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openFullPlayer(BuildContext context) async {
    await controller?.pause();
    if (!context.mounted) return;
    await showPostVideoDialog(
      context,
      url: widget.item.media.url,
      title: widget.item.post.title,
      postId: widget.item.post.id,
      providerName: widget.item.post.providerName,
      description: widget.item.post.description,
    );
    if (mounted && widget.active) await controller?.play();
  }
}

class _ShortAction extends StatelessWidget {
  const _ShortAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black45,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(icon, size: 26),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _ShortAvatar extends StatelessWidget {
  const _ShortAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'O' : name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF8A3FFC), Color(0xFFEF5DA8), Color(0xFFFFB648)]),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF24202F),
        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

void _message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
  );
}
