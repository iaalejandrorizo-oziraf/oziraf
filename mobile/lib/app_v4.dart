import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'app_v2.dart' as api;
import 'app_v3.dart' as core;
import 'auth_session.dart';

class OzirafApp extends StatelessWidget {
  const OzirafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Stack(
        children: [
          const Positioned.fill(child: core.OzirafApp()),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: ValueListenableBuilder<OzirafProfile?>(
                  valueListenable: OzirafSessionStore.profileNotifier,
                  builder: (context, profile, _) {
                    if (profile == null) return const SizedBox.shrink();
                    return _ProfileHeader(profile: profile);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final OzirafProfile profile;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showEditProfileDialog(context, profile),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileAvatar(profile: profile, size: 34),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17212B),
                        ),
                      ),
                      Text(
                        profile.accountType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF677282),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.edit_outlined, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.size,
    this.photoOverride,
  });

  final OzirafProfile profile;
  final double size;
  final String? photoOverride;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF863BFF), Color(0xFF47BFFF)],
        ),
      ),
      child: Text(
        profile.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final photo = (photoOverride ?? profile.profilePhoto).trim();
    if (photo.isEmpty) return fallback;

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

enum _ProfileNetwork { whatsapp, instagram, facebook, tiktok, x, website }

extension _ProfileNetworkDetails on _ProfileNetwork {
  String get label => switch (this) {
    _ProfileNetwork.whatsapp => 'WhatsApp',
    _ProfileNetwork.instagram => 'Instagram',
    _ProfileNetwork.facebook => 'Facebook',
    _ProfileNetwork.tiktok => 'TikTok',
    _ProfileNetwork.x => 'X',
    _ProfileNetwork.website => 'Sitio web',
  };

  String get hint => switch (this) {
    _ProfileNetwork.whatsapp => '+52 228 123 4567',
    _ProfileNetwork.instagram => '@usuario o enlace',
    _ProfileNetwork.facebook => 'Usuario, página o enlace',
    _ProfileNetwork.tiktok => '@usuario o enlace',
    _ProfileNetwork.x => '@usuario o enlace',
    _ProfileNetwork.website => 'https://misitio.com',
  };

  IconData get icon => switch (this) {
    _ProfileNetwork.whatsapp => Icons.chat_outlined,
    _ProfileNetwork.instagram => Icons.camera_alt_outlined,
    _ProfileNetwork.facebook => Icons.facebook_outlined,
    _ProfileNetwork.tiktok => Icons.music_note_outlined,
    _ProfileNetwork.x => Icons.alternate_email_outlined,
    _ProfileNetwork.website => Icons.language_outlined,
  };
}

_ProfileNetwork? _firstAvailableNetwork(Set<_ProfileNetwork> selected) {
  for (final network in _ProfileNetwork.values) {
    if (!selected.contains(network)) return network;
  }
  return null;
}

String _normalizeSocialValue(_ProfileNetwork network, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty || network == _ProfileNetwork.whatsapp) return value;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('www.') ||
      (value.contains('.') && !value.contains(' '))) {
    return 'https://$value';
  }

  final handle = value.replaceFirst(RegExp(r'^@'), '');
  return switch (network) {
    _ProfileNetwork.instagram => 'https://instagram.com/$handle',
    _ProfileNetwork.facebook => 'https://facebook.com/$handle',
    _ProfileNetwork.tiktok => 'https://tiktok.com/@$handle',
    _ProfileNetwork.x => 'https://x.com/$handle',
    _ProfileNetwork.website => value,
    _ProfileNetwork.whatsapp => value,
  };
}

String? _validateSocialValue(_ProfileNetwork network, String? rawValue) {
  final value = rawValue?.trim() ?? '';
  if (value.isEmpty) return null;
  if (network == _ProfileNetwork.whatsapp) {
    return value.length <= 30 ? null : 'El número es demasiado largo';
  }

  final normalized = _normalizeSocialValue(network, value);
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    return 'Escribe un usuario o enlace válido';
  }
  return null;
}

Future<void> _showEditProfileDialog(
  BuildContext context,
  OzirafProfile profile,
) async {
  final firstName = TextEditingController(text: profile.firstName);
  final lastName = TextEditingController(text: profile.lastName);
  final city = TextEditingController(text: profile.city);
  final state = TextEditingController(text: profile.state);
  final profession = TextEditingController(text: profile.profession);
  final phone = TextEditingController(text: profile.phone);
  final whatsapp = TextEditingController(text: profile.whatsapp);
  final instagram = TextEditingController(text: profile.instagramUrl);
  final facebook = TextEditingController(text: profile.facebookUrl);
  final tiktok = TextEditingController(text: profile.tiktokUrl);
  final x = TextEditingController(text: profile.xUrl);
  final website = TextEditingController(text: profile.websiteUrl);
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final socialControllers = <_ProfileNetwork, TextEditingController>{
    _ProfileNetwork.whatsapp: whatsapp,
    _ProfileNetwork.instagram: instagram,
    _ProfileNetwork.facebook: facebook,
    _ProfileNetwork.tiktok: tiktok,
    _ProfileNetwork.x: x,
    _ProfileNetwork.website: website,
  };
  final selectedNetworks = <_ProfileNetwork>{
    if (profile.whatsapp.isNotEmpty) _ProfileNetwork.whatsapp,
    if (profile.instagramUrl.isNotEmpty) _ProfileNetwork.instagram,
    if (profile.facebookUrl.isNotEmpty) _ProfileNetwork.facebook,
    if (profile.tiktokUrl.isNotEmpty) _ProfileNetwork.tiktok,
    if (profile.xUrl.isNotEmpty) _ProfileNetwork.x,
    if (profile.websiteUrl.isNotEmpty) _ProfileNetwork.website,
  };
  _ProfileNetwork? networkToAdd = _firstAvailableNetwork(selectedNetworks);
  var selectedPhoto = profile.profilePhoto;
  var saving = false;
  var pickingPhoto = false;
  String? message;

  Future<void> pickPhoto(ImageSource source, StateSetter setDialogState) async {
    if (pickingPhoto) return;
    setDialogState(() {
      pickingPhoto = true;
      message = null;
    });

    try {
      final image = await picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 65,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final lowerName = image.name.toLowerCase();
      final mimeType = lowerName.endsWith('.png')
          ? 'image/png'
          : lowerName.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      if (dataUrl.length > 88_000) {
        throw Exception(
          'La foto quedó demasiado grande. Elige otra imagen o usa una foto con menos detalle.',
        );
      }

      setDialogState(() {
        selectedPhoto = dataUrl;
        message = 'Foto lista. Presiona Guardar para aplicarla.';
      });
    } catch (e) {
      setDialogState(() {
        message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setDialogState(() => pickingPhoto = false);
    }
  }

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  _ProfileAvatar(
                    profile: profile,
                    size: 52,
                    photoOverride: selectedPhoto,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Editar perfil')),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _ProfileAvatar(
                                  profile: profile,
                                  size: 88,
                                  photoOverride: selectedPhoto,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Foto de perfil',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: pickingPhoto
                                          ? null
                                          : () => pickPhoto(
                                              ImageSource.gallery,
                                              setDialogState,
                                            ),
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text('Galería'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: pickingPhoto
                                          ? null
                                          : () => pickPhoto(
                                              ImageSource.camera,
                                              setDialogState,
                                            ),
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                      ),
                                      label: const Text('Cámara'),
                                    ),
                                  ],
                                ),
                                if (pickingPhoto) ...[
                                  const SizedBox(height: 10),
                                  const LinearProgressIndicator(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: firstName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Escribe tu nombre'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: lastName,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: profession,
                          decoration: const InputDecoration(
                            labelText: 'Profesión o actividad',
                            prefixIcon: Icon(Icons.work_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: city,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: state,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            prefixIcon: Icon(Icons.map_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.alternate_email_outlined),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Redes sociales',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                          DropdownButtonFormField<
                                            _ProfileNetwork
                                          >(
                                            key: ValueKey(networkToAdd),
                                            initialValue: networkToAdd,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                              labelText: 'Seleccionar red',
                                            ),
                                            items: _ProfileNetwork.values
                                                .where(
                                                  (network) => !selectedNetworks
                                                      .contains(network),
                                                )
                                                .map(
                                                  (network) => DropdownMenuItem(
                                                    value: network,
                                                    child: Text(
                                                      network.label,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged:
                                                selectedNetworks.length ==
                                                    _ProfileNetwork
                                                        .values
                                                        .length
                                                ? null
                                                : (value) => setDialogState(
                                                    () => networkToAdd = value,
                                                  ),
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      tooltip: 'Agregar red social',
                                      onPressed: networkToAdd == null
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                selectedNetworks.add(
                                                  networkToAdd!,
                                                );
                                                networkToAdd =
                                                    _firstAvailableNetwork(
                                                      selectedNetworks,
                                                    );
                                              });
                                            },
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                for (final network in _ProfileNetwork.values)
                                  if (selectedNetworks.contains(network)) ...[
                                    const SizedBox(height: 10),
                                    TextFormField(
                                      controller: socialControllers[network],
                                      keyboardType:
                                          network == _ProfileNetwork.whatsapp
                                          ? TextInputType.phone
                                          : TextInputType.url,
                                      decoration: InputDecoration(
                                        labelText: network.label,
                                        hintText: network.hint,
                                        prefixIcon: Icon(network.icon),
                                        suffixIcon: IconButton(
                                          tooltip: 'Quitar ${network.label}',
                                          onPressed: () {
                                            setDialogState(() {
                                              socialControllers[network]!
                                                  .clear();
                                              selectedNetworks.remove(network);
                                              networkToAdd ??= network;
                                            });
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                      ),
                                      validator: (value) =>
                                          _validateSocialValue(network, value),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            message!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: saving || pickingPhoto
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            saving = true;
                            message = null;
                          });
                          try {
                            final updated = await _ProfileApi.update(
                              firstName: firstName.text,
                              lastName: lastName.text,
                              city: city.text,
                              state: state.text,
                              profession: profession.text,
                              phone: phone.text,
                              profilePhoto: selectedPhoto,
                              whatsapp: _normalizeSocialValue(
                                _ProfileNetwork.whatsapp,
                                whatsapp.text,
                              ),
                              instagramUrl: _normalizeSocialValue(
                                _ProfileNetwork.instagram,
                                instagram.text,
                              ),
                              facebookUrl: _normalizeSocialValue(
                                _ProfileNetwork.facebook,
                                facebook.text,
                              ),
                              tiktokUrl: _normalizeSocialValue(
                                _ProfileNetwork.tiktok,
                                tiktok.text,
                              ),
                              xUrl: _normalizeSocialValue(
                                _ProfileNetwork.x,
                                x.text,
                              ),
                              websiteUrl: _normalizeSocialValue(
                                _ProfileNetwork.website,
                                website.text,
                              ),
                            );
                            OzirafSessionStore.profileNotifier.value = updated;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              message = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            });
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Guardando...' : 'Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    firstName.dispose();
    lastName.dispose();
    city.dispose();
    state.dispose();
    profession.dispose();
    phone.dispose();
    whatsapp.dispose();
    instagram.dispose();
    facebook.dispose();
    tiktok.dispose();
    x.dispose();
    website.dispose();
  }
}

Future<void> showOzirafEditProfileDialog(
  BuildContext context,
  OzirafProfile profile,
) {
  return _showEditProfileDialog(context, profile);
}

class _ProfileApi {
  static Future<OzirafProfile> update({
    required String firstName,
    required String lastName,
    required String city,
    required String state,
    required String profession,
    required String phone,
    required String profilePhoto,
    required String whatsapp,
    required String instagramUrl,
    required String facebookUrl,
    required String tiktokUrl,
    required String xUrl,
    required String websiteUrl,
  }) async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.isEmpty) {
      throw Exception('Tu sesión no está disponible. Vuelve a iniciar sesión.');
    }

    final body = <String, dynamic>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'profession': profession.trim(),
      'phone': phone.trim(),
      'whatsapp': whatsapp.trim(),
      'instagramUrl': instagramUrl.trim(),
      'facebookUrl': facebookUrl.trim(),
      'tiktokUrl': tiktokUrl.trim(),
      'xUrl': xUrl.trim(),
      'websiteUrl': websiteUrl.trim(),
    };

    final photo = profilePhoto.trim();
    if (photo.isNotEmpty) body['profilePhoto'] = photo;

    final response = await http
        .patch(
          Uri.parse('${api.OzirafApiClient.baseUrl}/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    Object? payload;
    try {
      payload = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      payload = response.body;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (payload is Map<String, dynamic>) {
        final value = payload['message'];
        if (value is String && value.trim().isNotEmpty) {
          throw Exception(value);
        }
        if (value is List && value.isNotEmpty) {
          throw Exception(value.join(', '));
        }
      }
      throw Exception('OZIRAF API ${response.statusCode}');
    }

    if (payload is! Map<String, dynamic>) {
      throw Exception('OZIRAF devolvió un perfil inválido.');
    }

    return OzirafProfile.fromJson(payload);
  }
}
