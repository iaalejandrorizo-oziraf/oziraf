import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'post_video_dialog.dart';

class OzirafApp extends StatefulWidget {
  const OzirafApp({super.key});

  @override
  State<OzirafApp> createState() => _OzirafAppState();
}

class _OzirafAppState extends State<OzirafApp> {
  final sessionStore = OzirafSessionStore();
  String? token;
  OzirafProfile? profile;
  bool restoring = true;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    final savedToken = await sessionStore.readToken();
    if (savedToken == null || savedToken.isEmpty) {
      if (mounted) setState(() => restoring = false);
      return;
    }

    try {
      var restoredProfile = await OzirafApiClient.fetchProfile(savedToken);
      final storedType = await sessionStore.readAccountType();
      if (storedType != null) {
        restoredProfile = restoredProfile.copyWith(accountType: storedType);
      } else {
        final mine = await OzirafApiClient.fetchMyPosts(savedToken);
        if (mine.isNotEmpty) {
          restoredProfile = restoredProfile.copyWith(
            accountType: OzirafAccountType.anunciante,
          );
          await sessionStore.saveAccountType(OzirafAccountType.anunciante);
        }
      }

      if (!mounted) return;
      setState(() {
        token = savedToken;
        profile = restoredProfile;
        restoring = false;
      });
    } catch (_) {
      await sessionStore.clear();
      if (!mounted) return;
      setState(() {
        token = null;
        profile = null;
        restoring = false;
      });
    }
  }

  Future<void> onLogin(String accessToken) async {
    var loadedProfile = await OzirafApiClient.fetchProfile(accessToken);
    final mine = await OzirafApiClient.fetchMyPosts(accessToken);
    final storedType = await sessionStore.readAccountType();
    final type =
        storedType ??
        (mine.isNotEmpty
            ? OzirafAccountType.anunciante
            : loadedProfile.accountType);
    loadedProfile = loadedProfile.copyWith(accountType: type);

    await sessionStore.saveToken(accessToken);
    await sessionStore.saveAccountType(type);

    if (!mounted) return;
    setState(() {
      token = accessToken;
      profile = loadedProfile;
    });
  }

  Future<void> logout() async {
    await sessionStore.clear();
    if (!mounted) return;
    setState(() {
      token = null;
      profile = null;
    });
  }

  Future<void> changeAccountType(OzirafAccountType type) async {
    await sessionStore.saveAccountType(type);
    if (!mounted || profile == null) return;
    setState(() => profile = profile!.copyWith(accountType: type));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OZIRAF',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OzirafColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: OzirafColors.background,
      ),
      home: restoring
          ? const OzirafLoadingScreen()
          : OzirafHome(
              token: token,
              profile: profile,
              onLogin: onLogin,
              onLogout: logout,
              onAccountTypeChanged: changeAccountType,
            ),
    );
  }
}

class OzirafLoadingScreen extends StatelessWidget {
  const OzirafLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OzirafMark(size: 66),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Recuperando tu sesión...'),
          ],
        ),
      ),
    );
  }
}

class OzirafColors {
  static const background = Color(0xFFF8FBFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF1F7FF);
  static const border = Color(0xFFDCE4EE);
  static const text = Color(0xFF17212B);
  static const muted = Color(0xFF677282);
  static const primary = Color(0xFF4285F4);
  static const primaryStrong = Color(0xFF1A73E8);
  static const primarySoft = Color(0xFFE8F0FE);
  static const accent = Color(0xFF34A853);
  static const danger = Color(0xFFEA4335);
  static const logoPrimary = Color(0xFF863BFF);
  static const logoAccent = Color(0xFF47BFFF);
}

enum OzirafTab { buscar, actividad, solicitudes, publicar, cuenta }

class OzirafHome extends StatefulWidget {
  const OzirafHome({
    super.key,
    required this.token,
    required this.profile,
    required this.onLogin,
    required this.onLogout,
    required this.onAccountTypeChanged,
  });

  final String? token;
  final OzirafProfile? profile;
  final Future<void> Function(String token) onLogin;
  final Future<void> Function() onLogout;
  final Future<void> Function(OzirafAccountType type) onAccountTypeChanged;

  @override
  State<OzirafHome> createState() => _OzirafHomeState();
}

class _OzirafHomeState extends State<OzirafHome> {
  OzirafTab tab = OzirafTab.buscar;

  bool get isAdvertiser =>
      widget.profile?.accountType == OzirafAccountType.anunciante;

  List<OzirafTab> get tabs => isAdvertiser
      ? const [
          OzirafTab.buscar,
          OzirafTab.actividad,
          OzirafTab.solicitudes,
          OzirafTab.publicar,
          OzirafTab.cuenta,
        ]
      : const [
          OzirafTab.buscar,
          OzirafTab.actividad,
          OzirafTab.solicitudes,
          OzirafTab.cuenta,
        ];

  @override
  void didUpdateWidget(covariant OzirafHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!tabs.contains(tab)) tab = OzirafTab.buscar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: OzirafColors.surface,
        surfaceTintColor: OzirafColors.surface,
        title: const Row(
          children: [
            OzirafMark(size: 38),
            SizedBox(width: 10),
            Text('OZIRAF', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          if (widget.profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: AccountBadge(type: widget.profile!.accountType),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabs.indexOf(tab),
        onDestinationSelected: (index) => setState(() => tab = tabs[index]),
        destinations: tabs
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label(isAdvertiser),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _body() {
    switch (tab) {
      case OzirafTab.buscar:
        return const SearchScreen();
      case OzirafTab.actividad:
        if (widget.token == null) {
          return const LoginRequiredPanel(
            title: 'Tu actividad',
            message: 'Inicia sesión para guardar favoritos y administrar tu actividad.',
          );
        }
        return isAdvertiser
            ? MyPostsScreen(token: widget.token!)
            : const PlaceholderPanel(
                icon: Icons.favorite_border,
                title: 'Favoritos',
                message: 'Aquí aparecerán los servicios que guardes.',
              );
      case OzirafTab.solicitudes:
        return widget.token == null
            ? const LoginRequiredPanel(
                title: 'Solicitudes',
                message: 'Inicia sesión para consultar tus solicitudes.',
              )
            : PlaceholderPanel(
                icon: Icons.chat_bubble_outline,
                title: isAdvertiser
                    ? 'Solicitudes recibidas'
                    : 'Mis solicitudes',
                message: isAdvertiser
                    ? 'Aquí aparecerán los contactos de personas interesadas en tus anuncios.'
                    : 'Aquí podrás dar seguimiento a tus solicitudes enviadas.',
              );
      case OzirafTab.publicar:
        return widget.token == null
            ? const LoginRequiredPanel(
                title: 'Publicar',
                message: 'Inicia sesión como anunciante para publicar.',
              )
            : const PlaceholderPanel(
                icon: Icons.add_business_outlined,
                title: 'Publicar servicio',
                message: 'Usa el botón Publicar para crear un anuncio con fotos y video.',
              );
      case OzirafTab.cuenta:
        return AccountScreen(
          token: widget.token,
          profile: widget.profile,
          onLogin: widget.onLogin,
          onLogout: widget.onLogout,
          onAccountTypeChanged: widget.onAccountTypeChanged,
        );
    }
  }
}

extension OzirafTabMeta on OzirafTab {
  IconData get icon => switch (this) {
    OzirafTab.buscar => Icons.search_outlined,
    OzirafTab.actividad => Icons.dashboard_outlined,
    OzirafTab.solicitudes => Icons.chat_bubble_outline,
    OzirafTab.publicar => Icons.add_circle_outline,
    OzirafTab.cuenta => Icons.person_outline,
  };

  IconData get selectedIcon => switch (this) {
    OzirafTab.buscar => Icons.search,
    OzirafTab.actividad => Icons.dashboard,
    OzirafTab.solicitudes => Icons.chat_bubble,
    OzirafTab.publicar => Icons.add_circle,
    OzirafTab.cuenta => Icons.person,
  };

  String label(bool advertiser) => switch (this) {
    OzirafTab.buscar => 'Buscar',
    OzirafTab.actividad => advertiser ? 'Mis anuncios' : 'Favoritos',
    OzirafTab.solicitudes => 'Solicitudes',
    OzirafTab.publicar => 'Publicar',
    OzirafTab.cuenta => 'Cuenta',
  };
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final searchController = TextEditingController();
  final cityController = TextEditingController();
  List<ServicePost> posts = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await OzirafApiClient.fetchPosts();
      if (!mounted) return;
      setState(() {
        posts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        posts = const [];
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<ServicePost> get filtered {
    final q = searchController.text.trim().toLowerCase();
    final city = cityController.text.trim().toLowerCase();
    return posts.where((post) {
      final value = '${post.title} ${post.description} ${post.category}'
          .toLowerCase();
      return (q.isEmpty || value.contains(q)) &&
          (city.isEmpty || post.city.toLowerCase().contains(city));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Encuentra lo que necesitas cerca de ti',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Buscar servicio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: cityController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined),
              labelText: 'Ciudad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            ErrorPanel(message: error!, onRetry: load)
          else if (filtered.isEmpty)
            const PlaceholderPanel(
              icon: Icons.search_off,
              title: 'Sin resultados',
              message: 'No hay publicaciones que coincidan con tu búsqueda.',
            )
          else
            ...filtered.map((post) => ServiceCard(post: post)),
        ],
      ),
    );
  }
}

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key, required this.token});
  final String token;

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  bool loading = true;
  String? error;
  List<ServicePost> posts = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await OzirafApiClient.fetchMyPosts(widget.token);
      if (!mounted) return;
      setState(() {
        posts = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mis publicaciones',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Estas publicaciones pertenecen a tu cuenta.',
            style: TextStyle(color: OzirafColors.muted),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            ErrorPanel(message: error!, onRetry: load)
          else if (posts.isEmpty)
            const PlaceholderPanel(
              icon: Icons.inventory_2_outlined,
              title: 'Aún no tienes publicaciones',
              message: 'Cuando publiques un servicio aparecerá aquí.',
            )
          else
            ...posts.map((post) => ServiceCard(post: post, owned: true)),
        ],
      ),
    );
  }
}

class PostMediaItem {
  const PostMediaItem({
    required this.id,
    required this.kind,
    required this.mimeType,
  });

  final String id;
  final String kind;
  final String mimeType;

  bool get isImage => kind.toUpperCase() == 'IMAGE';
  bool get isVideo => kind.toUpperCase() == 'VIDEO';

  String get url =>
      '${OzirafApiClient.baseUrl}/posts/media/$id${isVideo ? '?v=2' : ''}';

  factory PostMediaItem.fromJson(Map<String, dynamic> json) {
    return PostMediaItem(
      id: text(json['id']),
      kind: text(json['kind']),
      mimeType: text(json['mimeType']),
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.post, this.owned = false});
  final ServicePost post;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final images = post.media.where((item) => item.isImage).toList();
    final videos = post.media.where((item) => item.isVideo).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProviderAvatar(
                  photo: post.providerPhoto,
                  name: post.providerName,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        post.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: OzirafColors.primaryStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (owned) const Chip(label: Text('Tu anuncio')),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 190,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        images[index].url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: OzirafColors.surfaceSoft,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 5),
                Text(
                  '${images.length} fotos • desliza para verlas',
                  style: const TextStyle(
                    color: OzirafColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
            if (videos.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showPostVideoDialog(
                  context,
                  url: videos.first.url,
                  title: post.title,
                  postId: post.id,
                  providerName: post.providerName,
                  description: post.description,
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Ver video del trabajo'),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              post.description,
              style: const TextStyle(color: OzirafColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 17),
                const SizedBox(width: 4),
                Expanded(child: Text('${post.city}, ${post.state}')),
                Text(
                  post.price,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({
    required this.photo,
    required this.name,
    required this.size,
  });

  final String photo;
  final String name;
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
          colors: [OzirafColors.logoPrimary, OzirafColors.logoAccent],
        ),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * .32,
        ),
      ),
    );

    if (photo.trim().isEmpty) return fallback;

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

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'O';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.token,
    required this.profile,
    required this.onLogin,
    required this.onLogout,
    required this.onAccountTypeChanged,
  });

  final String? token;
  final OzirafProfile? profile;
  final Future<void> Function(String token) onLogin;
  final Future<void> Function() onLogout;
  final Future<void> Function(OzirafAccountType type) onAccountTypeChanged;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final loginKey = GlobalKey<FormState>();
  final registerKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPassword = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  bool busy = false;
  bool registerMode = false;
  OzirafAccountType newAccountType = OzirafAccountType.solicitante;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    firstName.dispose();
    lastName.dispose();
    registerEmail.dispose();
    registerPassword.dispose();
    city.dispose();
    state.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!loginKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final token = await OzirafApiClient.login(
        email: email.text,
        password: password.text,
      );
      await widget.onLogin(token);
      if (!mounted) return;
      password.clear();
      setState(() {
        busy = false;
        message = 'Sesión iniciada correctamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> register() async {
    if (!registerKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await OzirafApiClient.register(
        firstName: firstName.text,
        lastName: lastName.text,
        email: registerEmail.text,
        password: registerPassword.text,
        city: city.text,
        state: state.text,
      );
      final token = await OzirafApiClient.login(
        email: registerEmail.text,
        password: registerPassword.text,
      );
      await widget.onLogin(token);
      await widget.onAccountTypeChanged(newAccountType);
      if (!mounted) return;
      registerPassword.clear();
      setState(() {
        busy = false;
        registerMode = false;
        message = 'Cuenta creada e iniciada.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile != null && widget.token != null) {
      final profile = widget.profile!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mi cuenta',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: const TextStyle(color: OzirafColors.muted),
                  ),
                  if (profile.city.isNotEmpty || profile.state.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${profile.city}${profile.city.isNotEmpty && profile.state.isNotEmpty ? ', ' : ''}${profile.state}',
                    ),
                  ],
                  const SizedBox(height: 14),
                  AccountBadge(type: profile.accountType),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Usar OZIRAF como',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SegmentedButton<OzirafAccountType>(
            segments: const [
              ButtonSegment(
                value: OzirafAccountType.solicitante,
                icon: Icon(Icons.search),
                label: Text('Solicitante'),
              ),
              ButtonSegment(
                value: OzirafAccountType.anunciante,
                icon: Icon(Icons.campaign_outlined),
                label: Text('Anunciante'),
              ),
            ],
            selected: {profile.accountType},
            onSelectionChanged: (selection) =>
                widget.onAccountTypeChanged(selection.first),
          ),
          const SizedBox(height: 10),
          Text(
            profile.accountType == OzirafAccountType.anunciante
                ? 'Modo Anunciante: puedes administrar publicaciones y recibir solicitudes.'
                : 'Modo Solicitante: puedes buscar, guardar y contactar anunciantes.',
            style: const TextStyle(color: OzirafColors.muted),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: busy ? null : widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          registerMode ? 'Crear cuenta' : 'Iniciar sesión',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          registerMode ? 'Elige cómo quieres empezar a usar OZIRAF.' : 'Tu sesión quedará guardada de forma segura en este dispositivo.',
          style: const TextStyle(color: OzirafColors.muted),
        ),
        const SizedBox(height: 16),
        if (!registerMode)
          Form(
            key: loginKey,
            child: Column(
              children: [
                OzirafField(
                  controller: email,
                  label: 'Correo',
                  icon: Icons.email_outlined,
                  validator: emailValidator,
                ),
                OzirafField(
                  controller: password,
                  label: 'Contraseña',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: passwordValidator,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : login,
                    icon: const Icon(Icons.login),
                    label: Text(busy ? 'Entrando...' : 'Entrar'),
                  ),
                ),
              ],
            ),
          )
        else
          Form(
            key: registerKey,
            child: Column(
              children: [
                SegmentedButton<OzirafAccountType>(
                  segments: const [
                    ButtonSegment(
                      value: OzirafAccountType.solicitante,
                      label: Text('Solicitante'),
                      icon: Icon(Icons.search),
                    ),
                    ButtonSegment(
                      value: OzirafAccountType.anunciante,
                      label: Text('Anunciante'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                  ],
                  selected: {newAccountType},
                  onSelectionChanged: (value) =>
                      setState(() => newAccountType = value.first),
                ),
                const SizedBox(height: 14),
                OzirafField(
                  controller: firstName,
                  label: 'Nombre',
                  icon: Icons.person_outline,
                  validator: requiredValidator,
                ),
                OzirafField(
                  controller: lastName,
                  label: 'Apellido',
                  icon: Icons.badge_outlined,
                ),
                OzirafField(
                  controller: registerEmail,
                  label: 'Correo',
                  icon: Icons.email_outlined,
                  validator: emailValidator,
                ),
                OzirafField(
                  controller: registerPassword,
                  label: 'Contraseña',
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: passwordValidator,
                ),
                OzirafField(
                  controller: city,
                  label: 'Ciudad',
                  icon: Icons.location_city_outlined,
                ),
                OzirafField(
                  controller: state,
                  label: 'Estado',
                  icon: Icons.map_outlined,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : register,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(busy ? 'Creando...' : 'Crear cuenta'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  registerMode = !registerMode;
                  message = null;
                }),
          child: Text(registerMode ? 'Ya tengo cuenta' : 'Crear una cuenta'),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class OzirafField extends StatelessWidget {
  const OzirafField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class AccountBadge extends StatelessWidget {
  const AccountBadge({super.key, required this.type});
  final OzirafAccountType type;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        type == OzirafAccountType.anunciante
            ? Icons.campaign_outlined
            : Icons.search,
        size: 18,
      ),
      label: Text(type.label),
    );
  }
}

class OzirafMark extends StatelessWidget {
  const OzirafMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OzirafColors.logoPrimary, OzirafColors.logoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Center(
        child: Container(
          width: size * .36,
          height: size * .36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * .12),
          ),
        ),
      ),
    );
  }
}

class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 38, color: OzirafColors.primary),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: OzirafColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LoginRequiredPanel extends StatelessWidget {
  const LoginRequiredPanel({
    super.key,
    required this.title,
    required this.message,
  });
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPanel(
      icon: Icons.lock_outline,
      title: title,
      message: message,
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 34, color: OzirafColors.danger),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class ServicePost {
  const ServicePost({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.city,
    required this.state,
    required this.price,
    required this.providerName,
    required this.providerPhoto,
    required this.media,
    this.providerId = '',
    this.providerProfession = '',
    this.providerPhone = '',
    this.providerWhatsapp = '',
    this.providerInstagramUrl = '',
    this.providerFacebookUrl = '',
    this.providerTiktokUrl = '',
    this.providerXUrl = '',
    this.providerWebsiteUrl = '',
    this.averageRating,
    this.reviewCount = 0,
    this.latestReview,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String city;
  final String state;
  final String price;
  final String providerName;
  final String providerPhoto;
  final String providerId;
  final String providerProfession;
  final String providerPhone;
  final String providerWhatsapp;
  final String providerInstagramUrl;
  final String providerFacebookUrl;
  final String providerTiktokUrl;
  final String providerXUrl;
  final String providerWebsiteUrl;
  final List<PostMediaItem> media;
  final double? averageRating;
  final int reviewCount;
  final ServiceReviewPreview? latestReview;

  ServicePost withLatestReview(ServiceReviewPreview review) {
    return ServicePost(
      id: id,
      title: title,
      description: description,
      category: category,
      city: city,
      state: state,
      price: price,
      providerName: providerName,
      providerPhoto: providerPhoto,
      providerId: providerId,
      providerProfession: providerProfession,
      providerPhone: providerPhone,
      providerWhatsapp: providerWhatsapp,
      providerInstagramUrl: providerInstagramUrl,
      providerFacebookUrl: providerFacebookUrl,
      providerTiktokUrl: providerTiktokUrl,
      providerXUrl: providerXUrl,
      providerWebsiteUrl: providerWebsiteUrl,
      media: media,
      averageRating: averageRating,
      reviewCount: reviewCount,
      latestReview: review,
    );
  }

  factory ServicePost.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final provider = '${text(user['firstName'])} ${text(user['lastName'])}'
        .trim();
    final rawMedia = json['media'];
    final media = rawMedia is List
        ? rawMedia
              .whereType<Map<String, dynamic>>()
              .map(PostMediaItem.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList()
        : <PostMediaItem>[];
    final averageValue = json['averageRating'];
    final countValue = json['reviewCount'];
    final latestValue = json['latestReview'];

    return ServicePost(
      id: text(json['id']),
      title: text(json['title'], fallback: 'Servicio OZIRAF'),
      description: text(json['description'], fallback: 'Servicio disponible.'),
      category: text(json['category'], fallback: 'Servicio'),
      city: text(json['city'], fallback: 'Ciudad'),
      state: text(json['state'], fallback: 'Estado'),
      price: formatPrice(json['price']),
      providerName: provider.isEmpty ? 'Anunciante OZIRAF' : provider,
      providerPhoto: text(user['profilePhoto']),
      providerId: text(user['id']),
      providerProfession: text(user['profession']),
      providerPhone: text(user['phone']),
      providerWhatsapp: text(user['whatsapp']),
      providerInstagramUrl: text(user['instagramUrl']),
      providerFacebookUrl: text(user['facebookUrl']),
      providerTiktokUrl: text(user['tiktokUrl']),
      providerXUrl: text(user['xUrl']),
      providerWebsiteUrl: text(user['websiteUrl']),
      media: media,
      averageRating: averageValue is num ? averageValue.toDouble() : null,
      reviewCount: countValue is num ? countValue.toInt() : 0,
      latestReview: latestValue is Map<String, dynamic>
          ? ServiceReviewPreview.fromJson(latestValue)
          : null,
    );
  }
}

class ServiceReviewPreview {
  const ServiceReviewPreview({
    required this.rating,
    required this.comment,
    required this.authorName,
    required this.createdAt,
  });

  final int rating;
  final String comment;
  final String authorName;
  final DateTime? createdAt;

  factory ServiceReviewPreview.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : <String, dynamic>{};
    final name = '${text(author['firstName'])} ${text(author['lastName'])}'
        .trim();
    final ratingValue = json['rating'];

    return ServiceReviewPreview(
      rating: ratingValue is num ? ratingValue.toInt().clamp(0, 5) : 0,
      comment: text(json['comment']),
      authorName: name.isEmpty ? 'Usuario OZIRAF' : name,
      createdAt: DateTime.tryParse(text(json['createdAt'])),
    );
  }
}

class OzirafApiClient {
  static const webBaseUrl = String.fromEnvironment(
    'OZIRAF_API_URL',
    defaultValue: 'http://localhost:3001',
  );
  static const androidBaseUrl = String.fromEnvironment(
    'OZIRAF_ANDROID_API_URL',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidBaseUrl;
    }
    return webBaseUrl;
  }

  static Future<List<ServicePost>> fetchPosts() async {
    final response = await http
        .get(Uri.parse('$baseUrl/posts?page=1&limit=50'))
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
    return _hydrateLatestReviews(postsFromPayload(payload));
  }

  static Future<ServicePost> fetchPost(String postId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/posts/${Uri.encodeComponent(postId)}'))
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
    if (payload is! Map<String, dynamic>) {
      throw Exception('No se pudo cargar el anuncio compartido.');
    }
    final hydrated = await _hydrateLatestReviews([
      ServicePost.fromJson(payload),
    ]);
    return hydrated.single;
  }

  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
    if (payload is Map<String, dynamic>) {
      final token = text(payload['access_token']);
      if (token.isNotEmpty) return token;
    }
    throw Exception('El servidor no devolvió una sesión válida.');
  }

  static Future<OzirafProfile> fetchProfile(String token) async {
    final response = await http
        .get(Uri.parse('$baseUrl/users/profile'), headers: authHeaders(token))
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
    if (payload is Map<String, dynamic>) {
      return OzirafProfile.fromJson(payload);
    }
    throw Exception('No se pudo cargar el perfil.');
  }

  static Future<List<ServicePost>> fetchMyPosts(String token) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/posts/me?page=1&limit=50'),
          headers: authHeaders(token),
        )
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
    return _hydrateLatestReviews(postsFromPayload(payload));
  }

  static Future<List<ServicePost>> _hydrateLatestReviews(
    List<ServicePost> posts,
  ) async {
    return Future.wait(
      posts.map((post) async {
        if (post.reviewCount == 0 || post.latestReview != null) return post;

        try {
          final response = await http
              .get(
                Uri.parse(
                  '$baseUrl/reviews/posts/${Uri.encodeComponent(post.id)}'
                  '?page=1&limit=1',
                ),
              )
              .timeout(const Duration(seconds: 10));
          final payload = decodePayload(response.body);
          ensureSuccess(response.statusCode, payload);
          final data = payload is Map<String, dynamic> ? payload['data'] : null;
          if (data is! List || data.isEmpty) return post;
          final review = data.first;
          if (review is! Map<String, dynamic>) return post;
          return post.withLatestReview(ServiceReviewPreview.fromJson(review));
        } catch (_) {
          return post;
        }
      }),
    );
  }

  static Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String city,
    required String state,
  }) async {
    final body = <String, String>{
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'password': password,
      'city': city.trim(),
      'state': state.trim(),
    }..removeWhere((key, value) => value.isEmpty);

    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    final payload = decodePayload(response.body);
    ensureSuccess(response.statusCode, payload);
  }
}

Map<String, String> authHeaders(String token) => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer $token',
};

Object? decodePayload(String body) {
  if (body.trim().isEmpty) return null;
  try {
    return jsonDecode(body);
  } catch (_) {
    return body;
  }
}

void ensureSuccess(int status, Object? payload) {
  if (status >= 200 && status < 300) return;
  if (payload is Map<String, dynamic>) {
    final message = payload['message'];
    if (message is String && message.trim().isNotEmpty) {
      throw Exception(message);
    }
    if (message is List && message.isNotEmpty) {
      throw Exception(message.join(', '));
    }
  }
  throw Exception('OZIRAF API $status');
}

List<ServicePost> postsFromPayload(Object? payload) {
  Object? data = payload;
  if (payload is Map<String, dynamic>) data = payload['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(ServicePost.fromJson)
      .toList();
}

String text(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

String formatPrice(Object? value) {
  if (value is num && value > 0) {
    return '\$${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  }
  return 'Cotizar';
}

String? requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo requerido';
  return null;
}

String? emailValidator(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Campo requerido';
  if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
  return null;
}

String? passwordValidator(String? value) {
  if ((value ?? '').length < 8) return 'Mínimo 8 caracteres';
  return null;
}
