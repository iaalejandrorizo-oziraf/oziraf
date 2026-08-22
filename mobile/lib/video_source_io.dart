import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> prepareVideoController(String url) async {
  try {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return VideoPlayerController.networkUrl(uri);
    }

    final directory = await getTemporaryDirectory();
    final mediaId = uri.pathSegments.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : uri.pathSegments.last.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final extension = contentType.contains('quicktime')
        ? '.mov'
        : contentType.contains('webm')
            ? '.webm'
            : contentType.contains('3gpp')
                ? '.3gp'
                : '.mp4';
    final file = File('${directory.path}/oziraf_video_$mediaId$extension');

    final bytes = response.bodyBytes;
    if (!await file.exists() || await file.length() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }

    return VideoPlayerController.file(file);
  } catch (_) {
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }
}
