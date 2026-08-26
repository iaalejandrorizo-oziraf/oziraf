import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum _ShareTarget { whatsapp, instagram, facebook, tiktok, x, copy, more }

const _publicWebUrl = String.fromEnvironment(
  'OZIRAF_PUBLIC_WEB_URL',
  defaultValue: 'http://100.112.136.50:8092',
);

Future<void> showOzirafShareSheet(
  BuildContext context, {
  required String title,
  String description = '',
  String location = '',
  String price = '',
  String postId = '',
}) async {
  final text = _buildShareText(
    title: title,
    description: description,
    location: location,
    price: price,
  );
  final link = buildOzirafShareLink(postId);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final actions =
          <({_ShareTarget target, String label, Widget icon, Color color})>[
            (
              target: _ShareTarget.whatsapp,
              label: 'WhatsApp',
              icon: const Icon(Icons.chat_outlined),
              color: const Color(0xFF128C4A),
            ),
            (
              target: _ShareTarget.instagram,
              label: 'Instagram',
              icon: const Icon(Icons.camera_alt_outlined),
              color: const Color(0xFFC13584),
            ),
            (
              target: _ShareTarget.facebook,
              label: 'Facebook',
              icon: const Icon(Icons.facebook_outlined),
              color: const Color(0xFF1877F2),
            ),
            (
              target: _ShareTarget.tiktok,
              label: 'TikTok',
              icon: const Icon(Icons.music_note_outlined),
              color: const Color(0xFF111111),
            ),
            (
              target: _ShareTarget.x,
              label: 'X',
              icon: const Text(
                'X',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              color: const Color(0xFF111111),
            ),
            (
              target: _ShareTarget.copy,
              label: 'Copiar',
              icon: const Icon(Icons.link_outlined),
              color: const Color(0xFF5D6470),
            ),
            (
              target: _ShareTarget.more,
              label: 'Más opciones',
              icon: const Icon(Icons.more_horiz),
              color: const Color(0xFF654CFF),
            ),
          ];

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compartir en',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 360 ? 3 : 4;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final action in actions)
                      _ShareAction(
                        label: action.label,
                        icon: action.icon,
                        color: action.color,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _shareTo(
                            context,
                            action.target,
                            text: text,
                            link: link,
                            subject: title,
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

String _buildShareText({
  required String title,
  required String description,
  required String location,
  required String price,
}) {
  return [
    'Mira este servicio en OZIRAF:',
    title,
    description,
    location,
    if (price.trim().isNotEmpty) 'Desde ${price.trim()}',
  ].where((item) => item.trim().isNotEmpty).join('\n');
}

@visibleForTesting
Uri? buildOzirafShareLink(String postId, {Uri? currentBase}) {
  if (postId.trim().isEmpty) return null;
  final configured = Uri.tryParse(_publicWebUrl.trim());
  final base =
      configured != null && {'http', 'https'}.contains(configured.scheme)
      ? configured
      : currentBase ?? Uri.base;
  if (!{'http', 'https'}.contains(base.scheme)) return null;
  return base.replace(
    path: '/',
    queryParameters: {'post': postId.trim()},
    fragment: '',
  );
}

String? resolveOzirafSharedPostId([Uri? location]) {
  final value = (location ?? Uri.base).queryParameters['post']?.trim() ?? '';
  return value.isEmpty ? null : value;
}

Future<void> _shareTo(
  BuildContext context,
  _ShareTarget target, {
  required String text,
  required Uri? link,
  required String subject,
}) async {
  final content = link == null ? text : '$text\n$link';

  switch (target) {
    case _ShareTarget.whatsapp:
      await _launchOrShare(
        context,
        Uri.https('wa.me', '/', {'text': content}),
        text: content,
        subject: subject,
      );
      return;
    case _ShareTarget.facebook:
      if (link == null) {
        await _copyAndOpen(
          context,
          text: content,
          destination: Uri.parse('https://www.facebook.com/'),
          network: 'Facebook',
        );
        return;
      }
      await _launchOrShare(
        context,
        Uri.https('www.facebook.com', '/sharer/sharer.php', {
          'u': link.toString(),
          'quote': text,
        }),
        text: content,
        subject: subject,
      );
      return;
    case _ShareTarget.x:
      await _launchOrShare(
        context,
        Uri.https('x.com', '/intent/post', {
          'text': text,
          if (link != null) 'url': link.toString(),
        }),
        text: content,
        subject: subject,
      );
      return;
    case _ShareTarget.instagram:
      await _copyAndOpen(
        context,
        text: content,
        destination: Uri.parse('https://www.instagram.com/'),
        network: 'Instagram',
      );
      return;
    case _ShareTarget.tiktok:
      await _copyAndOpen(
        context,
        text: content,
        destination: Uri.parse('https://www.tiktok.com/'),
        network: 'TikTok',
      );
      return;
    case _ShareTarget.copy:
      await Clipboard.setData(ClipboardData(text: content));
      if (context.mounted) _message(context, 'Contenido copiado');
      return;
    case _ShareTarget.more:
      await _nativeShare(content, subject);
      return;
  }
}

Future<void> _launchOrShare(
  BuildContext context,
  Uri destination, {
  required String text,
  required String subject,
}) async {
  try {
    final opened = await launchUrl(
      destination,
      mode: LaunchMode.externalApplication,
    );
    if (opened) return;
  } catch (_) {
    // The native share panel remains available when a specific app cannot open.
  }
  await _nativeShare(text, subject);
  if (context.mounted) _message(context, 'Elige una aplicación para compartir');
}

Future<void> _copyAndOpen(
  BuildContext context, {
  required String text,
  required Uri destination,
  required String network,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  try {
    await launchUrl(destination, mode: LaunchMode.externalApplication);
  } catch (_) {
    // The copied content is still available if the destination cannot open.
  }
  if (context.mounted) {
    _message(context, 'Contenido copiado para $network');
  }
}

Future<void> _nativeShare(String text, String subject) async {
  await SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

void _message(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class _ShareAction extends StatelessWidget {
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: 25),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: color),
                child: icon,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
