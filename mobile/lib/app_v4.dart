import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  const _ProfileAvatar({required this.profile, required this.size});

  final OzirafProfile profile;
  final double size;

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

    final photo = profile.profilePhoto.trim();
    if (photo.isEmpty) return fallback;

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
  final photo = TextEditingController(text: profile.profilePhoto);
  final formKey = GlobalKey<FormState>();
  var saving = false;
  String? message;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  _ProfileAvatar(profile: profile, size: 44),
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
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: photo,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'URL de foto de perfil',
                            prefixIcon: Icon(Icons.photo_outlined),
                            helperText: 'La selección desde galería se añadirá después.',
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
                  onPressed: saving
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
                              profilePhoto: photo.text,
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
    photo.dispose();
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
        .timeout(const Duration(seconds: 10));

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
