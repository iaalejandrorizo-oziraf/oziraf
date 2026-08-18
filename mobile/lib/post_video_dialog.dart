import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Future<void> showPostVideoDialog(
  BuildContext context, {
  required String url,
  required String title,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog.fullscreen(
      child: _PostVideoPlayer(url: url, title: title),
    ),
  );
}

class _PostVideoPlayer extends StatefulWidget {
  const _PostVideoPlayer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final VideoPlayerController controller;
  late final Future<void> initializeFuture;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    initializeFuture = controller.initialize().then((_) async {
      await controller.setLooping(false);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
                final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      color: Colors.black,
                      child: Column(
                        children: [
                          VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          Row(
                            children: [
                              IconButton.filled(
                                onPressed: () {
                                  value.isPlaying ? controller.pause() : controller.play();
                                },
                                icon: Icon(
                                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Reiniciar',
                                color: Colors.white,
                                onPressed: () async {
                                  await controller.seekTo(Duration.zero);
                                  await controller.play();
                                },
                                icon: const Icon(Icons.replay),
                              ),
                            ],
                          ),
                        ],
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
