import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'auth_session.dart';

Future<void> showPostVideoDialog(
  BuildContext context, {
  required String url,
  required String title,
  String postId = '',
  String providerName = 'Anunciante OZIRAF',
  String description = '',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog.fullscreen(
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
  late final VideoPlayerController controller;
  late final Future<void> initializeFuture;
  bool favorite = false;
  bool favoriteLoading = false;
  String resolvedPostId = '';

  String get apiBase {
    final uri = Uri.parse(widget.url);
    final segments = [...uri.pathSegments];
    if (segments.length >= 3) {
      segments.removeRange(segments.length - 3, segments.length);
    }
    return uri
        .replace(pathSegments: segments, query: null, fragment: null)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  String get mediaId {
    final uri = Uri.parse(widget.url);
    return uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  }

  @override
  void initState() {
    super.initState();
    resolvedPostId = widget.postId;
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    initializeFuture = controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    });
    _resolvePostContext();
  }

  @override
  void dispose() {
    controller.dispose();
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
    await _loadFavoriteStatus();
    if (mounted) setState(() {});
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
    final details = widget.description.trim().isEmpty
        ? widget.title
        : '${widget.title}\n${widget.description}';
    await Share.share(
      'Mira este servicio en OZIRAF:\n$details',
      subject: widget.title,
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
      backgroundColor: Colors.white,
      builder: (_) => _CommentsSheet(
        apiBase: apiBase,
        postId: resolvedPostId,
      ),
    );
    if (mounted && wasPlaying) await controller.play();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError || !controller.value.isInitialized) {
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
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => value.isPlaying
                          ? controller.pause()
                          : controller.play(),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio:
                              value.aspectRatio > 0 ? value.aspectRatio : 9 / 16,
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
                      bottom: 70,
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
                            onPressed:
                                favoriteLoading ? null : _toggleFavorite,
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
        body: jsonEncode({
          'rating': rating,
          'comment': comment.text.trim(),
        }),
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
        setState(
          () => error = e.toString().replaceFirst('Exception: ', ''),
        );
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Comentarios',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null && comments.isEmpty
                      ? Center(child: Text(error!, textAlign: TextAlign.center))
                      : comments.isEmpty
                          ? const Center(
                              child: Text('Sé el primero en comentar.'),
                            )
                          : ListView.separated(
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = comments[index];
                                final text =
                                    item['comment']?.toString().trim() ?? '';
                                final stars = item['rating'] is num
                                    ? (item['rating'] as num).toInt()
                                    : 0;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    authorName(item),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('★' * stars),
                                      if (text.isNotEmpty) Text(text),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
            if (error != null && comments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Row(
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => rating = value),
                  icon: Icon(
                    value <= rating ? Icons.star : Icons.star_border,
                  ),
                );
              }),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: comment,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
