import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'auth_session.dart';
import 'oziraf_share.dart';
import 'video_source.dart';

Future<void> showPostVideoDialog(
  BuildContext context, {
  required String url,
  required String title,
  required String postId,
  String providerName = 'Anunciante OZIRAF',
  String description = '',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => buildOzirafVideoDialogFrame(
      dialogContext,
      child: _PostVideoPlayer(
        url: url,
        title: title,
        postId: postId,
        providerName: providerName,
        description: description,
      ),
    ),
  );
}

@visibleForTesting
Widget buildOzirafVideoDialogFrame(
  BuildContext context, {
  required Widget child,
  bool? embedded,
}) {
  if (!(embedded ?? kIsWeb)) return Dialog.fullscreen(child: child);

  final viewport = MediaQuery.sizeOf(context);
  final horizontalInset = viewport.width < 600 ? 12.0 : 32.0;
  final verticalInset = viewport.height < 600 ? 12.0 : 24.0;
  final availableWidth = viewport.width - (horizontalInset * 2);
  final availableHeight = viewport.height - (verticalInset * 2);
  final height = math.min(
    760.0,
    math.min(availableHeight, availableWidth * 16 / 9),
  );
  final width = height * 9 / 16;

  return Dialog(
    insetPadding: EdgeInsets.symmetric(
      horizontal: horizontalInset,
      vertical: verticalInset,
    ),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: SizedBox(
      key: const ValueKey('oziraf-embedded-video-frame'),
      width: width,
      height: height,
      child: child,
    ),
  );
}

@visibleForTesting
String resolveOzirafApiBase(String mediaUrl) {
  final uri = Uri.parse(mediaUrl);
  if (!{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
    throw FormatException('La URL del video no pertenece a OZIRAF.');
  }
  return uri.origin;
}

class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({
    required this.url,
    required this.title,
    required this.postId,
    required this.providerName,
    required this.description,
  });

  final String url;
  final String title;
  final String postId;
  final String providerName;
  final String description;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late VideoPlayerController controller;
  late final Future<void> initializeFuture;
  bool controllerReady = false;
  bool favorite = false;
  bool favoriteLoading = false;
  String resolvedPostId = '';
  Map<String, dynamic>? latestReview;
  int reviewTotal = 0;

  String get apiBase => resolveOzirafApiBase(widget.url);

  String get mediaId {
    final uri = Uri.parse(widget.url);
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  }

  @override
  void initState() {
    super.initState();
    resolvedPostId = widget.postId;
    initializeFuture = _initializeVideo();
    _resolvePostContext();
  }

  Future<void> _initializeVideo() async {
    controller = await prepareVideoController(widget.url);
    controllerReady = true;
    await controller.initialize();
    await controller.setLooping(true);
    await controller.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (controllerReady) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _resolvePostContext() async {
    if (resolvedPostId.isEmpty && mediaId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$apiBase/posts/media/$mediaId/context'),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final payload = jsonDecode(response.body);
          if (payload is Map<String, dynamic>) {
            resolvedPostId = payload['postId']?.toString() ?? '';
          }
        }
      } catch (_) {}
    }
    await Future.wait([_loadFavoriteStatus(), _loadReviewPreview()]);
    if (mounted) setState(() {});
  }

  Future<void> _loadReviewPreview() async {
    if (resolvedPostId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$apiBase/reviews/posts/$resolvedPostId?page=1&limit=1'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final payload = jsonDecode(response.body);
      if (!mounted || payload is! Map<String, dynamic>) return;
      final data = payload['data'];
      final values = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final totalValue = payload['total'];
      setState(() {
        latestReview = values.isEmpty ? null : values.first;
        reviewTotal = totalValue is num ? totalValue.toInt() : values.length;
      });
    } catch (_) {}
  }

  Future<void> _loadFavoriteStatus() async {
    if (resolvedPostId.isEmpty) return;
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$apiBase/favorites/$resolvedPostId/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final payload = jsonDecode(response.body);
      if (!mounted || payload is! Map<String, dynamic>) return;
      final value = payload['isFavorite'] ?? payload['favorite'];
      setState(() => favorite = value == true);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (resolvedPostId.isEmpty) {
      _showMessage('Todavía estamos cargando este anuncio.');
      return;
    }
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.isEmpty) {
      _showMessage('Inicia sesión para guardar anuncios.');
      return;
    }
    if (favoriteLoading) return;
    setState(() => favoriteLoading = true);
    try {
      final uri = Uri.parse('$apiBase/favorites/$resolvedPostId');
      final response = favorite
          ? await http.delete(uri, headers: {'Authorization': 'Bearer $token'})
          : await http.post(uri, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) setState(() => favorite = !favorite);
      } else {
        _showMessage('No se pudo actualizar Guardados.');
      }
    } catch (_) {
      _showMessage('No se pudo conectar con OZIRAF.');
    } finally {
      if (mounted) setState(() => favoriteLoading = false);
    }
  }

  Future<void> _share() async {
    await showOzirafShareSheet(
      context,
      title: widget.title,
      description: widget.description,
      postId: resolvedPostId,
    );
  }

  Future<void> _openComments() async {
    if (resolvedPostId.isEmpty) {
      _showMessage('Todavía estamos cargando este anuncio.');
      return;
    }
    final wasPlaying = controller.value.isPlaying;
    await controller.pause();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .32),
      constraints: kIsWeb ? const BoxConstraints(maxWidth: 430) : null,
      builder: (_) => _CommentsSheet(apiBase: apiBase, postId: resolvedPostId),
    );
    await _loadReviewPreview();
    if (mounted && wasPlaying) await controller.play();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _reviewAuthor(Map<String, dynamic> item) {
    final author = item['author'];
    if (author is! Map<String, dynamic>) return 'Usuario OZIRAF';
    final first = author['firstName']?.toString().trim() ?? '';
    final last = author['lastName']?.toString().trim() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Usuario OZIRAF' : name;
  }

  Widget _latestReviewPreview() {
    final item = latestReview!;
    final author = _reviewAuthor(item);
    final text = item['comment']?.toString().trim() ?? '';
    final ratingValue = item['rating'];
    final rating = ratingValue is num ? ratingValue.toDouble() : 0.0;
    final moreCount = math.max(0, reviewTotal - 1);

    return Material(
      color: Colors.black.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openComments,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white70,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text.isEmpty ? 'Sin comentario escrito' : text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      color: Color(0xFFF5B942),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$moreCount más',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebPlayer(VideoPlayerValue value) {
    final hasReview = latestReview != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          button: true,
          label: value.isPlaying ? 'Pausar video' : 'Reproducir video',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                value.isPlaying ? controller.pause() : controller.play(),
            child: ColoredBox(
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: value.size.width,
                  height: value.size.height,
                  child: VideoPlayer(controller),
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
                  Colors.black38,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0, .18, .56, 1],
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: IconButton.filledTonal(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        if (!value.isPlaying)
          const Center(
            child: IgnorePointer(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white70,
                size: 68,
              ),
            ),
          ),
        Positioned(
          right: 10,
          bottom: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SocialButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Comentar',
                onPressed: _openComments,
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.share_outlined,
                label: 'Compartir',
                onPressed: _share,
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: favorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: favorite ? 'Guardado' : 'Guardar',
                onPressed: favoriteLoading ? null : _toggleFavorite,
              ),
            ],
          ),
        ),
        Positioned(
          left: 14,
          right: 72,
          bottom: hasReview ? 116 : 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.providerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                ),
              ),
              if (widget.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (hasReview)
          Positioned(
            left: 10,
            right: 72,
            bottom: 34,
            child: _latestReviewPreview(),
          ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 6,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            colors: const VideoProgressColors(
              playedColor: Color(0xFF7C5CFF),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: initializeFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 14),
                        Text(
                          'Cargando video...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError ||
                !controllerReady ||
                !controller.value.isInitialized) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No se pudo reproducir este video.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              );
            }

            return ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasReview = latestReview != null;
                if (kIsWeb && MediaQuery.sizeOf(context).width >= 760) {
                  return _buildWebPlayer(value);
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => value.isPlaying
                          ? controller.pause()
                          : controller.play(),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: value.aspectRatio > 0
                              ? value.aspectRatio
                              : 9 / 16,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    if (!value.isPlaying)
                      const Center(
                        child: IgnorePointer(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white70,
                            size: 72,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 14,
                      right: 74,
                      bottom: hasReview ? 128 : 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.providerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(blurRadius: 5, color: Colors.black),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(blurRadius: 5, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasReview)
                      Positioned(
                        left: 10,
                        right: 74,
                        bottom: 40,
                        child: _latestReviewPreview(),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 72,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SocialButton(
                            icon: Icons.chat_bubble_outline,
                            label: 'Comentar',
                            onPressed: _openComments,
                          ),
                          const SizedBox(height: 14),
                          _SocialButton(
                            icon: Icons.share_outlined,
                            label: 'Compartir',
                            onPressed: _share,
                          ),
                          const SizedBox(height: 14),
                          _SocialButton(
                            icon: favorite
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: favorite ? 'Guardado' : 'Guardar',
                            onPressed: favoriteLoading ? null : _toggleFavorite,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 12,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
          ),
          icon: Icon(icon),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(blurRadius: 4, color: Colors.black)],
          ),
        ),
      ],
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.apiBase, required this.postId});

  final String apiBase;
  final String postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  static const _primary = Color(0xFF654CFF);
  static const _primarySoft = Color(0xFFF0EDFF);
  static const _text = Color(0xFF1D2130);
  static const _muted = Color(0xFF697080);
  static const _border = Color(0xFFE7E9F0);
  static const _star = Color(0xFFF5B942);

  final comment = TextEditingController();
  int rating = 5;
  bool loading = true;
  bool sending = false;
  String? error;
  List<Map<String, dynamic>> comments = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
          '${widget.apiBase}/reviews/posts/${widget.postId}?page=1&limit=50',
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudieron cargar los comentarios.');
      }
      final payload = jsonDecode(response.body);
      final data = payload is Map<String, dynamic> ? payload['data'] : payload;
      final values = data is List
          ? data.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        comments = values;
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

  Future<void> send() async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.isEmpty) {
      setState(() => error = 'Inicia sesión para comentar.');
      return;
    }
    if (comment.text.trim().isEmpty || sending) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('${widget.apiBase}/reviews/posts/${widget.postId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'rating': rating, 'comment': comment.text.trim()}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Object? payload;
        try {
          payload = jsonDecode(response.body);
        } catch (_) {}
        final message = payload is Map<String, dynamic>
            ? payload['message']
            : null;
        throw Exception(
          message is String ? message : 'No se pudo publicar el comentario.',
        );
      }
      comment.clear();
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String authorName(Map<String, dynamic> item) {
    final author = item['author'];
    if (author is! Map<String, dynamic>) return 'Usuario OZIRAF';
    final first = author['firstName']?.toString().trim() ?? '';
    final last = author['lastName']?.toString().trim() ?? '';
    final full = '$first $last'.trim();
    return full.isEmpty ? 'Usuario OZIRAF' : full;
  }

  String authorInitials(Map<String, dynamic> item) {
    final words = authorName(item)
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'O';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  int itemRating(Map<String, dynamic> item) {
    final value = item['rating'];
    return value is num ? value.toInt().clamp(0, 5) : 0;
  }

  String itemDate(Map<String, dynamic> item) {
    final value = item['createdAt']?.toString();
    final parsed = value == null ? null : DateTime.tryParse(value);
    if (parsed == null) return '';

    final date = parsed.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final commentDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(commentDay).inDays;
    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    if (difference == 0) return 'Hoy, $time';
    if (difference == 1) return 'Ayer, $time';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _ratingStars(int value, {double size = 15}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: index < value ? _star : const Color(0xFFB7BBC6),
        ),
      ),
    );
  }

  Widget _commentItem(Map<String, dynamic> item) {
    final name = authorName(item);
    final date = itemDate(item);
    final text = item['comment']?.toString().trim() ?? '';
    final stars = itemRating(item);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primarySoft,
            child: Text(
              authorInitials(item),
              style: const TextStyle(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        date,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _ratingStars(stars),
                    const SizedBox(width: 6),
                    Text(
                      stars.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF414654),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: _primarySoft,
              child: Icon(Icons.forum_outlined, color: _primary, size: 24),
            ),
            const SizedBox(height: 11),
            const Text(
              'Inicia la conversación',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              error ?? 'Sé la primera persona en dejar una opinión.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: error == null ? _muted : const Color(0xFFB42318),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 11),
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xBDF9F9FC),
        border: Border(top: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null && comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFB42318),
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFB42318),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Text(
                'Tu valoración',
                style: TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 7),
              ...List.generate(5, (index) {
                final value = index + 1;
                return SizedBox.square(
                  dimension: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: '$value ${value == 1 ? 'estrella' : 'estrellas'}',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => rating = value),
                    icon: Icon(
                      value <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: value <= rating ? _star : const Color(0xFFB7BBC6),
                      size: 20,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: comment,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  style: const TextStyle(color: _text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Escribe un comentario...',
                    hintStyle: const TextStyle(color: _muted),
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xD1FFFFFF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              SizedBox.square(
                dimension: 42,
                child: IconButton.filled(
                  tooltip: 'Publicar comentario',
                  style: IconButton.styleFrom(
                    backgroundColor: _primary,
                    disabledBackgroundColor: const Color(0xFFD6D2EA),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 21),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final viewport = MediaQuery.sizeOf(context);
    final floatingInset = kIsWeb ? 24.0 : 0.0;
    final availableHeight = math.max(
      340.0,
      viewport.height - bottom - floatingInset - 12,
    );
    final visibleReviewCount = math.min(comments.length, 2);
    final preferredHeight = kIsWeb
        ? 330.0 + (visibleReviewCount * 25)
        : viewport.height * .74;
    final sheetHeight = math.min(preferredHeight, availableHeight);
    final countLabel = comments.length == 1
        ? '1 opinión'
        : '${comments.length} opiniones';
    final averageRating = comments.isEmpty
        ? 0.0
        : comments.fold<int>(0, (sum, item) => sum + itemRating(item)) /
              comments.length;
    final panelRadius = kIsWeb
        ? BorderRadius.circular(8)
        : const BorderRadius.vertical(top: Radius.circular(8));

    return Padding(
      padding: EdgeInsets.only(bottom: bottom + floatingInset),
      child: Material(
        color: Colors.transparent,
        elevation: kIsWeb ? 18 : 0,
        shadowColor: Colors.black.withValues(alpha: .18),
        clipBehavior: Clip.antiAlias,
        borderRadius: panelRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB3FFFFFF),
              borderRadius: panelRadius,
              border: Border.all(color: const Color(0x99FFFFFF)),
            ),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              color: _primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Comentarios',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  loading
                                      ? 'Cargando opiniones...'
                                      : '${averageRating.toStringAsFixed(1)} ★ · $countLabel',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: _border),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _primary),
                          )
                        : comments.isEmpty
                        ? _emptyState()
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: comments.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 60,
                              endIndent: 16,
                              color: _border,
                            ),
                            itemBuilder: (context, index) =>
                                _commentItem(comments[index]),
                          ),
                  ),
                  _composer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
