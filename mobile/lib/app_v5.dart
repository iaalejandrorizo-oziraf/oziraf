import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_v2.dart' as api;
import 'app_v4.dart' as base;
import 'auth_session.dart';

class OzirafApp extends base.OzirafApp {
  const OzirafApp({super.key});

  @override
  Widget build(BuildContext context) {
    final inherited = super.build(context);
    if (inherited is! MaterialApp) return inherited;

    return MaterialApp(
      debugShowCheckedModeBanner: inherited.debugShowCheckedModeBanner,
      title: inherited.title,
      theme: inherited.theme,
      darkTheme: inherited.darkTheme,
      themeMode: inherited.themeMode,
      home: Stack(
        children: [
          Positioned.fill(child: inherited.home ?? const SizedBox.shrink()),
          Positioned(
            right: 16,
            bottom: 86,
            child: SafeArea(
              top: false,
              child: ValueListenableBuilder<OzirafProfile?>(
                valueListenable: OzirafSessionStore.profileNotifier,
                builder: (context, profile, _) {
                  if (profile == null ||
                      profile.accountType != OzirafAccountType.anunciante) {
                    return const SizedBox.shrink();
                  }

                  return FloatingActionButton.extended(
                    heroTag: 'oziraf-publish-service',
                    onPressed: () => _openPublishSheet(context, profile),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text(
                      'Publicar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openPublishSheet(
  BuildContext context,
  OzirafProfile profile,
) async {
  final createdTitle = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _PublishServiceSheet(profile: profile),
  );

  if (!context.mounted || createdTitle == null || createdTitle.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 44),
      title: const Text('Servicio publicado'),
      content: Text(
        '“$createdTitle” ya está guardado en OZIRAF y aparecerá en tus anuncios.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Listo'),
        ),
      ],
    ),
  );
}

class _PublishServiceSheet extends StatefulWidget {
  const _PublishServiceSheet({required this.profile});

  final OzirafProfile profile;

  @override
  State<_PublishServiceSheet> createState() => _PublishServiceSheetState();
}

class _PublishServiceSheetState extends State<_PublishServiceSheet> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final category = TextEditingController();
  final country = TextEditingController(text: 'México');
  final city = TextEditingController();
  final state = TextEditingController();
  final neighborhood = TextEditingController();
  final price = TextEditingController();

  bool saving = false;
  String? message;

  @override
  void initState() {
    super.initState();
    city.text = widget.profile.city;
    state.text = widget.profile.state;
    if (widget.profile.profession.trim().isNotEmpty) {
      category.text = widget.profile.profession.trim();
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    category.dispose();
    country.dispose();
    city.dispose();
    state.dispose();
    neighborhood.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> publish() async {
    if (saving || !formKey.currentState!.validate()) return;

    final rawPrice = price.text.trim().replaceAll(',', '.');
    final parsedPrice = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    if (rawPrice.isNotEmpty && (parsedPrice == null || parsedPrice <= 0)) {
      setState(() => message = 'Escribe un precio válido o deja el campo vacío.');
      return;
    }

    setState(() {
      saving = true;
      message = null;
    });

    try {
      await _PublishServiceApi.create(
        title: title.text,
        description: description.text,
        category: category.text,
        country: country.text,
        city: city.text,
        state: state.text,
        neighborhood: neighborhood.text,
        price: parsedPrice,
      );

      if (!mounted) return;
      Navigator.pop(context, title.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Publicar servicio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Describe claramente lo que ofreces. Después podrás administrarlo desde Mis anuncios.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título del servicio',
                  hintText: 'Ej. Clases de yoga para principiantes',
                  prefixIcon: Icon(Icons.campaign_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: description,
                minLines: 4,
                maxLines: 7,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Explica qué incluye el servicio, horarios, experiencia o cualquier detalle importante.',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: category,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej. Yoga, Construcción, Plomería, Contabilidad',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: country,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'País',
                        prefixIcon: Icon(Icons.public),
                        border: OutlineInputBorder(),
                      ),
                      validator: requiredField,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: state,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.map_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: requiredField,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: city,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: requiredField,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: neighborhood,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Colonia o zona (opcional)',
                  prefixIcon: Icon(Icons.place_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio (opcional)',
                  hintText: 'Déjalo vacío si prefieres “Cotizar”',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: r'$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : publish,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: Text(saving ? 'Publicando...' : 'Publicar servicio'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishServiceApi {
  static Future<Map<String, dynamic>> create({
    required String title,
    required String description,
    required String category,
    required String country,
    required String city,
    required String state,
    required String neighborhood,
    required double? price,
  }) async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Tu sesión no está disponible. Vuelve a iniciar sesión.');
    }

    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'country': country.trim(),
      'city': city.trim(),
      'state': state.trim(),
    };

    final cleanNeighborhood = neighborhood.trim();
    if (cleanNeighborhood.isNotEmpty) {
      body['neighborhood'] = cleanNeighborhood;
    }
    if (price != null) body['price'] = price;

    final response = await http
        .post(
          Uri.parse('${api.OzirafApiClient.baseUrl}/posts'),
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
      throw Exception('OZIRAF no devolvió el anuncio creado.');
    }

    return payload;
  }
}
