import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

class _PublishResult {
  const _PublishResult({required this.title, this.warning});

  final String title;
  final String? warning;
}

Future<void> _openPublishSheet(
  BuildContext context,
  OzirafProfile profile,
) async {
  final result = await showModalBottomSheet<_PublishResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _PublishServiceSheet(profile: profile),
  );

  if (!context.mounted || result == null || result.title.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 44),
      title: const Text('Servicio publicado'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${result.title}” ya está guardado en OZIRAF y aparecerá en tus anuncios.',
          ),
          if (result.warning != null) ...[
            const SizedBox(height: 12),
            Text(
              result.warning!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
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

Future<void> openOzirafPublishSheet(
  BuildContext context,
  OzirafProfile profile,
) {
  return _openPublishSheet(context, profile);
}

Future<bool> openOzirafEditPostSheet(
  BuildContext context,
  api.ServicePost post,
) async {
  final result = await showModalBottomSheet<_EditPostResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _EditPostSheet(post: post),
  );
  if (result?.warning != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result!.warning!)));
  }
  return result?.changed ?? false;
}

class _EditPostResult {
  const _EditPostResult({required this.changed, this.warning});

  final bool changed;
  final String? warning;
}

class _EditPostSheet extends StatefulWidget {
  const _EditPostSheet({required this.post});

  final api.ServicePost post;

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController description;
  late final TextEditingController category;
  late final TextEditingController city;
  late final TextEditingController state;
  late final TextEditingController price;
  final picker = ImagePicker();
  late List<api.PostMediaItem> existingMedia;
  final removedMediaIds = <String>{};
  List<XFile> newPhotos = [];
  XFile? newVideo;
  bool saving = false;
  bool pickingMedia = false;
  String? message;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.post.title);
    description = TextEditingController(text: widget.post.description);
    category = TextEditingController(text: widget.post.category);
    city = TextEditingController(text: widget.post.city);
    state = TextEditingController(text: widget.post.state);
    final rawPrice = widget.post.price.replaceAll(RegExp(r'[^0-9.,]'), '');
    price = TextEditingController(text: rawPrice.replaceAll(',', '.'));
    existingMedia = List<api.PostMediaItem>.from(widget.post.media);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    category.dispose();
    city.dispose();
    state.dispose();
    price.dispose();
    super.dispose();
  }

  String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo requerido';
    return null;
  }

  List<api.PostMediaItem> get keptImages => existingMedia
      .where((item) => item.isImage && !removedMediaIds.contains(item.id))
      .toList();

  List<api.PostMediaItem> get keptVideos => existingMedia
      .where((item) => item.isVideo && !removedMediaIds.contains(item.id))
      .toList();

  Future<void> pickPhotos() async {
    if (pickingMedia || saving) return;
    final available = 4 - keptImages.length - newPhotos.length;
    if (available <= 0) {
      setState(() => message = 'Quita una foto actual para agregar otra.');
      return;
    }
    setState(() {
      pickingMedia = true;
      message = null;
    });
    try {
      final selected = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (!mounted) return;
      final accepted = selected.take(available).toList();
      setState(() {
        newPhotos = [...newPhotos, ...accepted];
        if (selected.length > available) {
          message = 'Solo quedan $available espacios para fotos.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> takePhoto() async {
    if (pickingMedia || saving) return;
    final available = 4 - keptImages.length - newPhotos.length;
    if (available <= 0) {
      setState(() => message = 'Quita una foto actual para agregar otra.');
      return;
    }
    setState(() {
      pickingMedia = true;
      message = null;
    });
    try {
      final selected = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (!mounted) return;
      if (selected != null) {
        setState(() => newPhotos = [...newPhotos, selected]);
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> pickVideo(ImageSource source) async {
    if (pickingMedia || saving) return;
    setState(() {
      pickingMedia = true;
      message = null;
    });
    try {
      final selected = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 15),
      );
      if (!mounted || selected == null) return;
      setState(() {
        for (final video in keptVideos) {
          removedMediaIds.add(video.id);
        }
        newVideo = selected;
        message = 'Video listo. Máximo 15 segundos y 12 MB.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || saving) return;
    final cleanPrice = price.text.trim().replaceAll(',', '.');
    final parsedPrice = cleanPrice.isEmpty ? null : double.tryParse(cleanPrice);
    if (cleanPrice.isNotEmpty && (parsedPrice == null || parsedPrice <= 0)) {
      setState(
        () => message = 'Escribe un precio válido o deja el campo vacío.',
      );
      return;
    }

    setState(() {
      saving = true;
      message = null;
    });
    try {
      await _PublishServiceApi.update(
        postId: widget.post.id,
        title: title.text,
        description: description.text,
        category: category.text,
        city: city.text,
        state: state.text,
        price: parsedPrice,
        clearPrice: cleanPrice.isEmpty,
      );

      final failedMedia = <String>[];
      for (final mediaId in removedMediaIds) {
        try {
          await _PublishServiceApi.removeMedia(
            postId: widget.post.id,
            mediaId: mediaId,
          );
        } catch (_) {
          failedMedia.add('quitar un archivo');
        }
      }
      for (final photo in newPhotos) {
        try {
          await _PublishServiceApi.uploadMedia(
            postId: widget.post.id,
            file: photo,
          );
        } catch (_) {
          failedMedia.add('subir una foto');
        }
      }
      if (newVideo != null) {
        try {
          await _PublishServiceApi.uploadMedia(
            postId: widget.post.id,
            file: newVideo!,
          );
        } catch (_) {
          failedMedia.add('subir el video');
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        _EditPostResult(
          changed: true,
          warning: failedMedia.isEmpty
              ? null
              : 'La información se guardó, pero no se pudo ${failedMedia.toSet().join(' ni ')}. Abre Editar para intentarlo otra vez.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        4,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editar publicación',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fotos y video',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: pickingMedia || saving
                                  ? null
                                  : pickPhotos,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Agregar fotos'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: pickingMedia || saving
                                  ? null
                                  : takePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Tomar foto'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: pickingMedia || saving
                                  ? null
                                  : () => pickVideo(ImageSource.gallery),
                              icon: const Icon(Icons.video_library_outlined),
                              label: Text(
                                keptVideos.isEmpty && newVideo == null
                                    ? 'Agregar video'
                                    : 'Cambiar video',
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: pickingMedia || saving
                                  ? null
                                  : () => pickVideo(ImageSource.camera),
                              icon: const Icon(Icons.videocam_outlined),
                              label: const Text('Grabar video'),
                            ),
                          ],
                        ),
                        if (pickingMedia) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                        if (existingMedia.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...existingMedia.asMap().entries.map((entry) {
                            final media = entry.value;
                            final removed = removedMediaIds.contains(media.id);
                            return Opacity(
                              opacity: removed ? .5 : 1,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: media.isImage
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          media.url,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.image_outlined),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.movie_outlined,
                                        size: 34,
                                      ),
                                title: Text(
                                  media.isImage
                                      ? 'Foto actual ${entry.key + 1}'
                                      : 'Video actual',
                                ),
                                subtitle: Text(
                                  removed
                                      ? 'Se quitará al guardar'
                                      : 'Archivo publicado',
                                ),
                                trailing: IconButton(
                                  tooltip: removed
                                      ? 'Conservar archivo'
                                      : 'Quitar archivo',
                                  onPressed: saving
                                      ? null
                                      : () => setState(() {
                                          if (removed) {
                                            if (media.isImage &&
                                                keptImages.length +
                                                        newPhotos.length >=
                                                    4) {
                                              message = 'Quita una foto nueva antes de restaurar esta foto.';
                                              return;
                                            }
                                            if (media.isVideo &&
                                                newVideo != null) {
                                              newVideo = null;
                                            }
                                            removedMediaIds.remove(media.id);
                                          } else {
                                            removedMediaIds.add(media.id);
                                          }
                                        }),
                                  icon: Icon(
                                    removed
                                        ? Icons.undo_rounded
                                        : Icons.delete_outline,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                        if (newPhotos.isNotEmpty) ...[
                          const Divider(),
                          ...newPhotos.asMap().entries.map(
                            (entry) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              title: Text('Foto nueva ${entry.key + 1}'),
                              subtitle: Text(
                                entry.value.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Quitar foto nueva',
                                onPressed: saving
                                    ? null
                                    : () => setState(() {
                                        newPhotos = [
                                          for (
                                            var i = 0;
                                            i < newPhotos.length;
                                            i++
                                          )
                                            if (i != entry.key) newPhotos[i],
                                        ];
                                      }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),
                        ],
                        if (newVideo != null) ...[
                          const Divider(),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.video_file_outlined),
                            title: const Text('Video nuevo'),
                            subtitle: Text(
                              newVideo!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Quitar video nuevo',
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                      newVideo = null;
                                      for (final media in existingMedia) {
                                        if (media.isVideo) {
                                          removedMediaIds.remove(media.id);
                                        }
                                      }
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Título del servicio',
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
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
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
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
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
                        controller: city,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad',
                          prefixIcon: Icon(Icons.location_city_outlined),
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
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    hintText: 'Vacío para mostrar Cotizar',
                    prefixIcon: Icon(Icons.payments_outlined),
                    prefixText: r'$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Guardando...' : 'Guardar cambios'),
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
      ),
    );
  }
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
  final picker = ImagePicker();

  List<XFile> photos = const [];
  XFile? video;
  bool saving = false;
  bool pickingMedia = false;
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

  Future<void> pickPhotos() async {
    if (pickingMedia || saving) return;
    setState(() {
      pickingMedia = true;
      message = null;
    });

    try {
      final selected = await picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (!mounted) return;

      final limited = selected.take(4).toList();
      setState(() {
        photos = limited;
        if (selected.length > 4) {
          message = 'Se usarán las primeras 4 fotos seleccionadas.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> pickVideo(ImageSource source) async {
    if (pickingMedia || saving) return;
    setState(() {
      pickingMedia = true;
      message = null;
    });

    try {
      final selected = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 15),
      );
      if (!mounted) return;
      if (selected != null) {
        setState(() {
          video = selected;
          message = 'Video listo. Máximo 15 segundos y 12 MB.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> publish() async {
    if (saving || !formKey.currentState!.validate()) return;

    final rawPrice = price.text.trim().replaceAll(',', '.');
    final parsedPrice = rawPrice.isEmpty ? null : double.tryParse(rawPrice);
    if (rawPrice.isNotEmpty && (parsedPrice == null || parsedPrice <= 0)) {
      setState(
        () => message = 'Escribe un precio válido o deja el campo vacío.',
      );
      return;
    }

    setState(() {
      saving = true;
      message = photos.isNotEmpty || video != null
          ? 'Publicando anuncio y subiendo archivos...'
          : null;
    });

    try {
      final created = await _PublishServiceApi.create(
        title: title.text,
        description: description.text,
        category: category.text,
        country: country.text,
        city: city.text,
        state: state.text,
        neighborhood: neighborhood.text,
        price: parsedPrice,
      );

      final postId = api.text(created['id']);
      if (postId.isEmpty) {
        throw Exception('OZIRAF no devolvió el identificador del anuncio.');
      }

      final failedUploads = <String>[];
      for (final photo in photos) {
        try {
          await _PublishServiceApi.uploadMedia(postId: postId, file: photo);
        } catch (_) {
          failedUploads.add('una foto');
        }
      }

      if (video != null) {
        try {
          await _PublishServiceApi.uploadMedia(postId: postId, file: video!);
        } catch (_) {
          failedUploads.add('el video');
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        _PublishResult(
          title: title.text.trim(),
          warning: failedUploads.isEmpty
              ? null
              : 'El anuncio sí quedó publicado, pero no se pudo subir ${failedUploads.join(' y ')}. Puedes volver a intentarlo más adelante.',
        ),
      );
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
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Describe claramente lo que ofreces. Puedes agregar hasta 4 fotos y 1 video corto.',
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fotos y video del trabajo',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Hasta 4 fotos y 1 video de máximo 15 segundos.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: pickingMedia || saving
                                ? null
                                : pickPhotos,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              photos.isEmpty
                                  ? 'Agregar fotos'
                                  : '${photos.length} foto${photos.length == 1 ? '' : 's'}',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: pickingMedia || saving
                                ? null
                                : () => pickVideo(ImageSource.gallery),
                            icon: const Icon(Icons.video_library_outlined),
                            label: Text(
                              video == null ? 'Elegir video' : 'Cambiar video',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: pickingMedia || saving
                                ? null
                                : () => pickVideo(ImageSource.camera),
                            icon: const Icon(Icons.videocam_outlined),
                            label: const Text('Grabar video'),
                          ),
                        ],
                      ),
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...photos.asMap().entries.map(
                          (entry) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.image_outlined),
                            title: Text(
                              'Foto ${entry.key + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              entry.value.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Quitar foto',
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                      photos = [
                                        for (var i = 0; i < photos.length; i++)
                                          if (i != entry.key) photos[i],
                                      ];
                                    }),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      ],
                      if (video != null)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.movie_outlined),
                          title: const Text(
                            'Video seleccionado',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            video!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Quitar video',
                            onPressed: saving
                                ? null
                                : () => setState(() => video = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      if (pickingMedia) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  onPressed: saving || pickingMedia ? null : publish,
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
  static Future<void> removeMedia({
    required String postId,
    required String mediaId,
  }) async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Tu sesión no está disponible. Vuelve a iniciar sesión.');
    }

    final response = await http
        .delete(
          Uri.parse(
            '${api.OzirafApiClient.baseUrl}/posts/$postId/media/$mediaId',
          ),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    final payload = _decode(response.body);
    _ensureSuccess(response.statusCode, payload);
  }

  static Future<void> update({
    required String postId,
    required String title,
    required String description,
    required String category,
    required String city,
    required String state,
    required double? price,
    required bool clearPrice,
  }) async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Tu sesión no está disponible. Vuelve a iniciar sesión.');
    }

    final response = await http
        .patch(
          Uri.parse('${api.OzirafApiClient.baseUrl}/posts/$postId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title.trim(),
            'description': description.trim(),
            'category': category.trim(),
            'city': city.trim(),
            'state': state.trim(),
            'price': clearPrice ? null : price,
          }),
        )
        .timeout(const Duration(seconds: 15));

    final payload = _decode(response.body);
    _ensureSuccess(response.statusCode, payload);
  }

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

    final payload = _decode(response.body);
    _ensureSuccess(response.statusCode, payload);

    if (payload is! Map<String, dynamic>) {
      throw Exception('OZIRAF no devolvió el anuncio creado.');
    }

    return payload;
  }

  static Future<void> uploadMedia({
    required String postId,
    required XFile file,
  }) async {
    final token = OzirafSessionStore.tokenNotifier.value;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Tu sesión no está disponible. Vuelve a iniciar sesión.');
    }

    final bytes = await file.readAsBytes();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${api.OzirafApiClient.baseUrl}/posts/$postId/media'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    final payload = _decode(response.body);
    _ensureSuccess(response.statusCode, payload);
  }

  static Object? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static void _ensureSuccess(int status, Object? payload) {
    if (status >= 200 && status < 300) return;
    if (payload is Map<String, dynamic>) {
      final value = payload['message'];
      if (value is String && value.trim().isNotEmpty) {
        throw Exception(value);
      }
      if (value is List && value.isNotEmpty) {
        throw Exception(value.join(', '));
      }
    }
    throw Exception('OZIRAF API $status');
  }
}
