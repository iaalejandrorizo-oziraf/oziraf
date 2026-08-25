import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_v2.dart' as core;
import 'social_feed.dart';
import 'video_source.dart';

@visibleForTesting
Size resolveOzirafShortFrame(Size available) {
  final heightLimit = math.max(320.0, available.height - 28);
  final frameHeight = math.min(780.0, heightLimit);
  final widthLimit = math.max(240.0, math.min(460.0, available.width - 140));
  final frameWidth = math.min(frameHeight * 9 / 16, widthLimit);
  return Size(frameWidth, frameWidth * 16 / 9);
}

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({
    super.key,
    this.onOpenHome,
    this.onRequireAccount,
    this.onOpenMessages,
  });

  final VoidCallback? onOpenHome;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  final PageController pageController = PageController();
  List<_ShortItem> items = const [];
  bool loading = true;
  String? error;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void showShort(int index) {
    if (index < 0 || index >= items.length || !pageController.hasClients) {
      return;
    }
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
                FilledButton.tonal(
                  onPressed: load,
                  child: const Text('Reintentar'),
                ),
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
                Icon(
                  Icons.video_library_outlined,
                  color: Colors.white70,
                  size: 52,
                ),
                SizedBox(height: 12),
                Text(
                  'Todavía no hay Shorts publicados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
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
        controller: pageController,
        scrollDirection: Axis.vertical,
        itemCount: items.length,
        onPageChanged: (value) => setState(() => currentIndex = value),
        itemBuilder: (context, index) {
          return _ShortVideoPage(
            key: ValueKey('${items[index].post.id}-${items[index].media.id}'),
            item: items[index],
            active: index == currentIndex,
            position: index + 1,
            total: items.length,
            onOpenHome: widget.onOpenHome,
            onRequireAccount: widget.onRequireAccount,
            onOpenMessages: widget.onOpenMessages,
            onPrevious: index > 0 ? () => showShort(index - 1) : null,
            onNext: index < items.length - 1
                ? () => showShort(index + 1)
                : null,
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
    required this.position,
    required this.total,
    this.onOpenHome,
    this.onRequireAccount,
    this.onOpenMessages,
    this.onPrevious,
    this.onNext,
  });

  final _ShortItem item;
  final bool active;
  final int position;
  final int total;
  final VoidCallback? onOpenHome;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<_ShortVideoPage> createState() => _ShortVideoPageState();
}

class _ShortVideoPageState extends State<_ShortVideoPage> {
  VideoPlayerController? controller;
  bool initializing = true;
  bool failed = false;
  bool muted = false;

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

  void toggleMuted() {
    final player = controller;
    if (player == null || !player.value.isInitialized) return;
    final nextMuted = !muted;
    player.setVolume(nextMuted ? 0 : 1);
    setState(() => muted = nextMuted);
  }

  Future<void> openComments(core.ServicePost post) async {
    final wasPlaying = controller?.value.isPlaying ?? false;
    await controller?.pause();
    if (!mounted) return;
    await openOzirafComments(
      context,
      post,
      onRequireAccount: widget.onRequireAccount,
    );
    if (mounted && wasPlaying && widget.active) await controller?.play();
  }

  Widget _videoSurface(VideoPlayerController? player) {
    if (failed) {
      return const Icon(
        Icons.videocam_off_outlined,
        color: Colors.white54,
        size: 58,
      );
    }
    if (initializing || player == null || !player.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: player.value.size.width,
        height: player.value.size.height,
        child: VideoPlayer(player),
      ),
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    core.ServicePost post,
    VideoPlayerController? player,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameSize = resolveOzirafShortFrame(constraints.biggest);
        final initialized = player != null && player.value.isInitialized;

        return ColoredBox(
          color: const Color(0xFFF5F6FA),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 16,
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xFF654CFF),
                      size: 23,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Shorts',
                      style: TextStyle(
                        color: Color(0xFF242533),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${widget.position} de ${widget.total}',
                      style: const TextStyle(
                        color: Color(0xFF7A7D89),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        key: const ValueKey('oziraf-shorts-web-frame'),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: frameSize.width,
                          height: frameSize.height,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Semantics(
                                button: true,
                                label: initialized && player.value.isPlaying
                                    ? 'Pausar video'
                                    : 'Reproducir video',
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: togglePlayback,
                                  child: ColoredBox(
                                    color: Colors.black,
                                    child: Center(child: _videoSurface(player)),
                                  ),
                                ),
                              ),
                              const IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black38,
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black87,
                                      ],
                                      stops: [0, .17, .5, 1],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 10,
                                top: 10,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        post.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton.filledTonal(
                                      tooltip: muted
                                          ? 'Activar sonido'
                                          : 'Silenciar',
                                      onPressed: toggleMuted,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black45,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(36, 36),
                                        maximumSize: const Size(36, 36),
                                      ),
                                      icon: Icon(
                                        muted
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        size: 19,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (initialized && !player.value.isPlaying)
                                const Center(
                                  child: IgnorePointer(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white70,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 14,
                                right: 14,
                                bottom: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        _ShortAvatar(
                                          name: post.providerName,
                                          size: 36,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      post.providerName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.verified_rounded,
                                                    color: Color(0xFF69A5FF),
                                                    size: 15,
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${post.city}, ${post.state}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: () => openOzirafContact(
                                            context,
                                            post,
                                            onRequireAccount:
                                                widget.onRequireAccount,
                                            onOpenMessages:
                                                widget.onOpenMessages,
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF654CFF,
                                            ),
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(0, 34),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_outlined,
                                            size: 15,
                                          ),
                                          label: const Text(
                                            'Contactar',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      post.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      post.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sell_outlined,
                                          color: Colors.white70,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          post.price,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _ShortReviewPreview(
                                      post: post,
                                      onTap: () => openComments(post),
                                    ),
                                  ],
                                ),
                              ),
                              if (initialized)
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  bottom: 2,
                                  child: VideoProgressIndicator(
                                    player,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    colors: const VideoProgressColors(
                                      playedColor: Color(0xFF7C5CFF),
                                      bufferedColor: Colors.white38,
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 76,
                      height: frameSize.height,
                      child: Column(
                        children: [
                          _ShortNavButton(
                            tooltip: 'Short anterior',
                            icon: Icons.keyboard_arrow_up_rounded,
                            onPressed: widget.onPrevious,
                          ),
                          const SizedBox(height: 8),
                          _ShortNavButton(
                            tooltip: 'Short siguiente',
                            icon: Icons.keyboard_arrow_down_rounded,
                            onPressed: widget.onNext,
                          ),
                          const Spacer(),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: SocialActionsStore.likedPostIds,
                            builder: (context, liked, _) => _ShortAction(
                              icon: liked.contains(post.id)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              label: 'Me gusta',
                              active: liked.contains(post.id),
                              light: true,
                              onPressed: () => toggleOzirafLike(context, post),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _ShortAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: post.reviewCount == 1
                                ? '1 opinión'
                                : '${post.reviewCount} opiniones',
                            light: true,
                            onPressed: () => openComments(post),
                          ),
                          const SizedBox(height: 12),
                          _ShortAction(
                            icon: Icons.share_outlined,
                            label: 'Compartir',
                            light: true,
                            onPressed: () => shareOzirafPost(context, post),
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<Set<String>>(
                            valueListenable: SocialActionsStore.savedPostIds,
                            builder: (context, saved, _) => _ShortAction(
                              icon: saved.contains(post.id)
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              label: saved.contains(post.id)
                                  ? 'Guardado'
                                  : 'Guardar',
                              active: saved.contains(post.id),
                              light: true,
                              onPressed: () => toggleOzirafFavorite(
                                context,
                                post,
                                onRequireAccount: widget.onRequireAccount,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.item.post;
    final player = controller;

    if (kIsWeb && MediaQuery.sizeOf(context).width >= 760) {
      return _buildWebLayout(context, post, player);
    }

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
                  ? const Icon(
                      Icons.videocam_off_outlined,
                      color: Colors.white54,
                      size: 58,
                    )
                  : initializing ||
                        player == null ||
                        !player.value.isInitialized
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
                colors: [
                  Colors.black26,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
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
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: muted ? 'Activar sonido' : 'Silenciar',
                  onPressed: toggleMuted,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: 'Volver al inicio',
                  onPressed: widget.onOpenHome,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.home_outlined),
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
                ValueListenableBuilder<Set<String>>(
                  valueListenable: SocialActionsStore.likedPostIds,
                  builder: (context, liked, _) => _ShortAction(
                    icon: liked.contains(post.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: 'Me gusta',
                    active: liked.contains(post.id),
                    onPressed: () => toggleOzirafLike(context, post),
                  ),
                ),
                const SizedBox(height: 14),
                _ShortAction(
                  icon: Icons.chat_bubble_outline,
                  label: post.reviewCount == 1
                      ? '1 opinión'
                      : '${post.reviewCount} opiniones',
                  onPressed: () => openComments(post),
                ),
                const SizedBox(height: 14),
                _ShortAction(
                  icon: Icons.send_outlined,
                  label: 'Compartir',
                  onPressed: () => shareOzirafPost(context, post),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: SocialActionsStore.savedPostIds,
                  builder: (context, saved, _) => _ShortAction(
                    icon: saved.contains(post.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    label: 'Guardar',
                    active: saved.contains(post.id),
                    onPressed: () => toggleOzirafFavorite(
                      context,
                      post,
                      onRequireAccount: widget.onRequireAccount,
                    ),
                  ),
                ),
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
                    const Icon(
                      Icons.verified,
                      size: 17,
                      color: Color(0xFF6DA7FF),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${post.category} • ${post.city}, ${post.state}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF654CFF),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        post.price,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => openOzirafContact(
                        context,
                        post,
                        onRequireAccount: widget.onRequireAccount,
                        onOpenMessages: widget.onOpenMessages,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF252232),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
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
        Positioned(
          left: 12,
          right: 82,
          bottom: 34,
          child: SafeArea(
            top: false,
            child: _ShortReviewPreview(
              post: post,
              onTap: () => openComments(post),
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
}

class _ShortReviewPreview extends StatelessWidget {
  const _ShortReviewPreview({required this.post, required this.onTap});

  final core.ServicePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final review = post.latestReview;
    final count = post.reviewCount;
    final average = post.averageRating ?? 0;
    final countLabel = count == 1 ? '1 opinión' : '$count opiniones';

    return Material(
      color: Colors.black.withValues(alpha: .66),
      borderRadius: BorderRadius.circular(7),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                count == 0
                    ? Icons.star_outline_rounded
                    : Icons.reviews_outlined,
                color: count == 0 ? Colors.white70 : const Color(0xFFF5B942),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: count == 0
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sin opiniones todavía',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sé la primera persona en calificar.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                average.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF5B942),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  countLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                if (review != null)
                                  TextSpan(
                                    text: '${review.authorName}: ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                TextSpan(
                                  text: review == null
                                      ? 'Ver las calificaciones del servicio'
                                      : review.comment.trim().isEmpty
                                      ? 'Calificación sin comentario'
                                      : review.comment.trim(),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortNavButton extends StatelessWidget {
  const _ShortNavButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333543),
        disabledBackgroundColor: const Color(0xFFE7E8ED),
        disabledForegroundColor: const Color(0xFFAAADB7),
        side: const BorderSide(color: Color(0xFFDDDFE6)),
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(icon, size: 27),
    );
  }
}

class _ShortAction extends StatelessWidget {
  const _ShortAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.light = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: light ? Colors.white : Colors.black45,
            foregroundColor: active
                ? light
                      ? const Color(0xFF654CFF)
                      : const Color(0xFFFF5B7A)
                : light
                ? const Color(0xFF333543)
                : Colors.white,
            side: light
                ? const BorderSide(color: Color(0xFFDDDFE6))
                : BorderSide.none,
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(icon, size: 26),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: light ? const Color(0xFF555866) : Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            shadows: light
                ? const []
                : const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

class _ShortAvatar extends StatelessWidget {
  const _ShortAvatar({required this.name, this.size = 50});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'O'
        : name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .05),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8A3FFC), Color(0xFFEF5DA8), Color(0xFFFFB648)],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: const Color(0xFF24202F),
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .34,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
