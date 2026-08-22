import 'package:video_player/video_player.dart';

Future<VideoPlayerController> prepareVideoController(String url) async {
  return VideoPlayerController.networkUrl(Uri.parse(url));
}
