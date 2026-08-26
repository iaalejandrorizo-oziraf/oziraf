import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_v2.dart' as core;

const _purple = Color(0xFF654CFF);
const _purpleSoft = Color(0xFFF0EDFF);
const _text = Color(0xFF191A22);
const _muted = Color(0xFF737787);
const _border = Color(0xFFE5E3EC);

enum OzirafSocialNetwork {
  whatsapp,
  instagram,
  facebook,
  tiktok,
  x,
  website,
  phone,
}

Future<void> showOzirafProviderProfile(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onContact,
}) async {
  final links = _providerLinks(post);
  final profession = post.providerProfession.trim().isEmpty
      ? post.category
      : post.providerProfession.trim();
  final rating = post.averageRating ?? 0;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .34),
    constraints: const BoxConstraints(maxWidth: 500),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Material(
            color: const Color(0xE8FFFFFF),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle_outlined,
                        color: _purple,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Perfil profesional',
                          style: TextStyle(
                            color: _text,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 18),
                  Center(
                    child: _ProviderAvatar(
                      photo: post.providerPhoto,
                      name: post.providerName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          post.providerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF4285F4),
                        size: 19,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profession,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _purple,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${post.city}, ${post.state}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .58),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF5B942),
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          post.reviewCount == 0
                              ? 'Aún sin calificaciones'
                              : '${rating.toStringAsFixed(1)} · ${post.reviewCount == 1 ? '1 opinión' : '${post.reviewCount} opiniones'}',
                          style: const TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Contacto y redes',
                      style: TextStyle(
                        color: _text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final link in links)
                          OutlinedButton.icon(
                            onPressed: () => openOzirafSocialLink(
                              sheetContext,
                              link.value,
                              link.network,
                            ),
                            icon: Icon(link.icon, size: 18),
                            label: Text(link.label),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: link.color,
                              backgroundColor: Colors.white.withValues(
                                alpha: .64,
                              ),
                              side: BorderSide(
                                color: link.color.withValues(alpha: .24),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: onContact == null
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              onContact();
                            },
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Contactar por OZIRAF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> openOzirafSocialLink(
  BuildContext context,
  String value,
  OzirafSocialNetwork network,
) async {
  final destination = resolveOzirafSocialUri(value, network);
  if (destination == null) {
    _message(context, 'Este vínculo todavía no está disponible');
    return;
  }

  try {
    final opened = await launchUrl(
      destination,
      mode: LaunchMode.externalApplication,
    );
    if (opened) return;
  } catch (_) {
    // The message below keeps the failure understandable to the user.
  }
  if (context.mounted) _message(context, 'No se pudo abrir este vínculo');
}

@visibleForTesting
Uri? resolveOzirafSocialUri(String rawValue, OzirafSocialNetwork network) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;

  if (network == OzirafSocialNetwork.whatsapp ||
      network == OzirafSocialNetwork.phone) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (network == OzirafSocialNetwork.phone) {
      return Uri(scheme: 'tel', path: digits);
    }
    return Uri.https('wa.me', '/${digits.replaceFirst('+', '')}');
  }

  final parsed = Uri.tryParse(value);
  if (parsed != null && {'http', 'https'}.contains(parsed.scheme)) {
    return parsed;
  }

  final handle = value.replaceFirst(RegExp(r'^@'), '');
  return switch (network) {
    OzirafSocialNetwork.instagram => Uri.https('instagram.com', '/$handle'),
    OzirafSocialNetwork.facebook => Uri.https('facebook.com', '/$handle'),
    OzirafSocialNetwork.tiktok => Uri.https('tiktok.com', '/@$handle'),
    OzirafSocialNetwork.x => Uri.https('x.com', '/$handle'),
    OzirafSocialNetwork.website => Uri.https(value, '/'),
    OzirafSocialNetwork.whatsapp || OzirafSocialNetwork.phone => null,
  };
}

List<_ProviderLink> _providerLinks(core.ServicePost post) {
  return [
    if (post.providerWhatsapp.isNotEmpty)
      _ProviderLink(
        label: 'WhatsApp',
        value: post.providerWhatsapp,
        network: OzirafSocialNetwork.whatsapp,
        icon: Icons.chat_outlined,
        color: const Color(0xFF128C4A),
      ),
    if (post.providerInstagramUrl.isNotEmpty)
      _ProviderLink(
        label: 'Instagram',
        value: post.providerInstagramUrl,
        network: OzirafSocialNetwork.instagram,
        icon: Icons.camera_alt_outlined,
        color: const Color(0xFFC13584),
      ),
    if (post.providerFacebookUrl.isNotEmpty)
      _ProviderLink(
        label: 'Facebook',
        value: post.providerFacebookUrl,
        network: OzirafSocialNetwork.facebook,
        icon: Icons.facebook_outlined,
        color: const Color(0xFF1877F2),
      ),
    if (post.providerTiktokUrl.isNotEmpty)
      _ProviderLink(
        label: 'TikTok',
        value: post.providerTiktokUrl,
        network: OzirafSocialNetwork.tiktok,
        icon: Icons.music_note_outlined,
        color: const Color(0xFF111111),
      ),
    if (post.providerXUrl.isNotEmpty)
      _ProviderLink(
        label: 'X',
        value: post.providerXUrl,
        network: OzirafSocialNetwork.x,
        icon: Icons.alternate_email_rounded,
        color: const Color(0xFF111111),
      ),
    if (post.providerWebsiteUrl.isNotEmpty)
      _ProviderLink(
        label: 'Sitio web',
        value: post.providerWebsiteUrl,
        network: OzirafSocialNetwork.website,
        icon: Icons.language_rounded,
        color: const Color(0xFF654CFF),
      ),
    if (post.providerPhone.isNotEmpty)
      _ProviderLink(
        label: 'Teléfono',
        value: post.providerPhone,
        network: OzirafSocialNetwork.phone,
        icon: Icons.phone_outlined,
        color: const Color(0xFF35606A),
      ),
  ];
}

class _ProviderLink {
  const _ProviderLink({
    required this.label,
    required this.value,
    required this.network,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final OzirafSocialNetwork network;
  final IconData icon;
  final Color color;
}

class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({required this.photo, required this.name});

  final String photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'O'
        : name.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 82,
      height: 82,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF654CFF), Color(0xFF4CA5FF)],
        ),
      ),
      child: CircleAvatar(
        backgroundColor: _purpleSoft,
        foregroundImage: photo.trim().isEmpty ? null : NetworkImage(photo),
        child: Text(
          initial,
          style: const TextStyle(
            color: _purple,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

void _message(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
