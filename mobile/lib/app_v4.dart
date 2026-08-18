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
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
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
                                      icon: const Icon(Icons.photo_library_outlined),
                                      label: const Text('Galería'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: pickingPhoto
                                          ? null
                                          : () => pickPhoto(
                                                ImageSource.camera,
                                                setDialogState,
                                              ),
                                      icon: const Icon(Icons.photo_camera_outlined),
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
                            );
                            OzirafSessionStore.profileNotifier.value = updated;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              message = e
                                  .toString()
                                  .replaceFirst('Exception: ', '');
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
  }
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
