import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'app_v2.dart' as core;
import 'app_v3.dart' as account;
import 'app_v4.dart' as profile_editor;
import 'app_v5.dart' as publish;
import 'admin_dashboard.dart';
import 'auth_session.dart';
import 'oziraf_share.dart';
import 'shorts_feed.dart';
import 'social_api.dart';
import 'social_feed.dart';

class OzirafApp extends StatefulWidget {
  const OzirafApp({super.key});

  @override
  State<OzirafApp> createState() => _OzirafAppState();
}

class _OzirafAppState extends State<OzirafApp> {
  final sessionStore = OzirafSessionStore();
  final String? initialPostId = resolveOzirafSharedPostId();
  String? token;
  OzirafProfile? profile;
  bool restoring = true;

  @override
  void initState() {
    super.initState();
    OzirafSessionStore.profileNotifier.addListener(_profileChanged);
    restoreSession();
  }

  @override
  void dispose() {
    OzirafSessionStore.profileNotifier.removeListener(_profileChanged);
    super.dispose();
  }

  void _profileChanged() {
    final updated = OzirafSessionStore.profileNotifier.value;
    if (mounted && updated != null && updated != profile) {
      setState(() => profile = updated);
    }
  }

  Future<void> restoreSession() async {
    final savedToken = await sessionStore.readToken();
    if (savedToken == null || savedToken.trim().isEmpty) {
      if (mounted) setState(() => restoring = false);
      return;
    }

    final cachedProfile = await sessionStore.readProfile();
    if (cachedProfile != null && mounted) {
      setState(() {
        token = savedToken;
        profile = cachedProfile;
        restoring = false;
      });
    }

    try {
      var restoredProfile = await core.OzirafApiClient.fetchProfile(savedToken);
      final storedType = await sessionStore.readAccountType();
      if (storedType != null) {
        restoredProfile = restoredProfile.copyWith(accountType: storedType);
      }
      await sessionStore.saveProfile(restoredProfile);
      await _syncSocialData(savedToken);
      if (!mounted) return;
      setState(() {
        token = savedToken;
        profile = restoredProfile;
        restoring = false;
      });
    } catch (error) {
      final unauthorized =
          error is core.OzirafApiException && error.isUnauthorized;
      if (!unauthorized && cachedProfile != null) return;
      if (unauthorized) {
        await sessionStore.clear();
        SocialActionsStore.clearSessionData();
      }
      if (!mounted) return;
      setState(() {
        token = unauthorized ? null : savedToken;
        profile = unauthorized ? null : cachedProfile;
        restoring = false;
      });
    }
  }

  Future<void> onLogin(String accessToken) async {
    var loadedProfile = await core.OzirafApiClient.fetchProfile(accessToken);
    final mine = await core.OzirafApiClient.fetchMyPosts(accessToken);
    if (mine.isNotEmpty) {
      loadedProfile = loadedProfile.copyWith(
        accountType: OzirafAccountType.anunciante,
      );
    }
    await sessionStore.saveToken(accessToken);
    await sessionStore.saveAccountType(loadedProfile.accountType);
    await sessionStore.saveProfile(loadedProfile);
    await _syncSocialData(accessToken);
    if (!mounted) return;
    setState(() {
      token = accessToken;
      profile = loadedProfile;
    });
  }

  Future<void> logout() async {
    await sessionStore.clear();
    SocialActionsStore.clearSessionData();
    if (!mounted) return;
    setState(() {
      token = null;
      profile = null;
    });
  }

  Future<void> changeAccountType(OzirafAccountType type) async {
    await sessionStore.saveAccountType(type);
    final current = profile;
    if (!mounted || current == null) return;
    final updated = current.copyWith(accountType: type);
    await sessionStore.saveProfile(updated);
    if (!mounted) return;
    setState(() => profile = updated);
  }

  Future<void> _syncSocialData(String accessToken) async {
    try {
      final values = await Future.wait([
        OzirafSocialApi.fetchFavorites(accessToken),
        OzirafSocialApi.fetchReceived(accessToken),
      ]);
      final favorites = values[0] as List<core.ServicePost>;
      final received = values[1] as List<OzirafContactLead>;
      SocialActionsStore.savedPostIds.value = {
        for (final post in favorites) post.id,
      };
      SocialActionsStore.unreadLeadCount.value = received
          .where((lead) => lead.status == 'NEW')
          .length;
    } catch (_) {
      SocialActionsStore.clearSessionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OZIRAF',
      theme: _socialTheme(null),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ),
      home: restoring
          ? const _SessionLoadingScreen()
          : _SocialShell(
              token: token,
              profile: profile,
              onLogin: onLogin,
              onLogout: logout,
              onAccountTypeChanged: changeAccountType,
              initialPostId: initialPostId,
            ),
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandHeader(),
            SizedBox(height: 18),
            CircularProgressIndicator(color: Color(0xFF654CFF)),
            SizedBox(height: 10),
            Text('Recuperando tu sesión...'),
          ],
        ),
      ),
    );
  }
}

ThemeData _socialTheme(ThemeData? inherited) {
  final baseTheme = inherited ?? ThemeData(useMaterial3: true);
  return baseTheme.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    cardTheme: const CardThemeData(color: Colors.white),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFEDE9FF),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? const Color(0xFF654CFF) : const Color(0xFF656A78),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? const Color(0xFF654CFF) : const Color(0xFF555B69),
        );
      }),
    ),
  );
}

class _SocialShell extends StatefulWidget {
  const _SocialShell({
    required this.token,
    required this.profile,
    required this.onLogin,
    required this.onLogout,
    required this.onAccountTypeChanged,
    this.initialPostId,
  });

  final String? token;
  final OzirafProfile? profile;
  final Future<void> Function(String token) onLogin;
  final Future<void> Function() onLogout;
  final Future<void> Function(OzirafAccountType type) onAccountTypeChanged;
  final String? initialPostId;

  @override
  State<_SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<_SocialShell> {
  int index = 0;

  void requireAccount() => setState(() => index = 4);
  void openMessages() => setState(() => index = 3);

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1100;

    if (desktop) {
      return Scaffold(
        backgroundColor: index == 1 ? Colors.black : const Color(0xFFF7F8FC),
        body: Row(
          children: [
            _DesktopNav(
              selected: index,
              isAdmin: widget.profile?.isAdmin ?? false,
              onSelected: (value) => setState(() => index = value),
            ),
            const VerticalDivider(width: 1, color: Color(0xFFE7E9F0)),
            Expanded(
              child: Column(
                children: [
                  if (index != 1)
                    _DesktopTopBar(
                      onNotifications: () => setState(() => index = 6),
                      onAccount: () => setState(() => index = 4),
                    ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: index == 1 ? Colors.black : const Color(0xFFF7F8FC),
      appBar: index == 0
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              titleSpacing: 12,
              title: const _BrandHeader(compact: true),
              actions: [
                if (widget.profile?.isAdmin ?? false)
                  IconButton(
                    tooltip: 'Administración',
                    onPressed: () => setState(() => index = 7),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => index = 6),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: SocialActionsStore.unreadLeadCount,
                      builder: (context, count, _) => count == 0
                          ? const SizedBox.shrink()
                          : const Positioned(
                              right: 11,
                              top: 11,
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: Color(0xFFEA4335),
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                _MobileProfileAction(onTap: () => setState(() => index = 4)),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (index) {
          5 => 4,
          4 => 5,
          >= 0 && <= 3 => index,
          _ => 0,
        },
        onDestinationSelected: (value) => setState(
          () => index = switch (value) {
            4 => 5,
            5 => 4,
            _ => value,
          },
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle_fill),
            label: 'Shorts',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Publicar',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mensajes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Guardados',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (index == 0) {
      return SocialFeedScreen(
        initialPostId: widget.initialPostId,
        onPublish: () => setState(() => index = 2),
        onOpenSaved: () => setState(() => index = 5),
        onRequireAccount: requireAccount,
        onOpenMessages: openMessages,
      );
    }
    if (index == 1) {
      return ShortsFeedScreen(
        onOpenHome: () => setState(() => index = 0),
        onRequireAccount: requireAccount,
        onOpenMessages: openMessages,
      );
    }
    if (index == 2) {
      return _MyPublicationsEnvironment(onGoAccount: requireAccount);
    }
    if (index == 3) {
      return _MessagesEnvironment(
        token: widget.token,
        onGoAccount: requireAccount,
      );
    }
    if (index == 5) {
      return _SavedEnvironment(
        token: widget.token,
        onGoAccount: requireAccount,
        onOpenMessages: openMessages,
      );
    }
    if (index == 6) {
      return _NotificationsEnvironment(
        token: widget.token,
        onGoAccount: requireAccount,
        onOpenMessages: openMessages,
      );
    }
    if (index == 7) {
      final accessToken = widget.token;
      if (accessToken == null || accessToken.trim().isEmpty) {
        return const _UtilityEnvironment(
          icon: Icons.lock_outline,
          title: 'Área de administración',
          subtitle: 'Inicia sesión con una cuenta administradora.',
          cards: [],
        );
      }
      return OzirafAdminDashboard(token: accessToken);
    }

    final accountScreen = account.OzirafAccountScreen(
      token: widget.token,
      profile: widget.profile,
      onLogin: widget.onLogin,
      onLogout: widget.onLogout,
      onAccountTypeChanged: widget.onAccountTypeChanged,
      onGoHome: () => setState(() => index = 0),
      onEditProfile: widget.profile == null
          ? null
          : () => profile_editor.showOzirafEditProfileDialog(
              context,
              widget.profile!,
            ),
    );
    return ColoredBox(
      color: const Color(0xFFF7F8FC),
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth >= 900 ? 720 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: accountScreen,
          ),
        ),
      ),
    );
  }
}

class _MobileProfileAction extends StatelessWidget {
  const _MobileProfileAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OzirafProfile?>(
      valueListenable: OzirafSessionStore.profileNotifier,
      builder: (context, profile, _) {
        final name = profile == null
            ? 'Entrar'
            : profile.firstName.trim().isNotEmpty
            ? profile.firstName.trim()
            : profile.fullName;

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 112),
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE7E9F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShellProfileAvatar(profile: profile, size: 30),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1D2130),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.onNotifications,
    required this.onAccount,
  });

  final VoidCallback onNotifications;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE7E9F0))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Encuentra servicios cerca de ti',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF1D2130),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Stack(
            children: [
              IconButton.filledTonal(
                tooltip: 'Notificaciones',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0EDFF),
                  foregroundColor: const Color(0xFF654CFF),
                ),
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              ValueListenableBuilder<int>(
                valueListenable: SocialActionsStore.unreadLeadCount,
                builder: (context, count, _) => count == 0
                    ? const SizedBox.shrink()
                    : const Positioned(
                        right: 10,
                        top: 10,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFEA4335),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<OzirafProfile?>(
            valueListenable: OzirafSessionStore.profileNotifier,
            builder: (context, profile, _) {
              final name = profile?.fullName ?? 'Entrar';
              final subtitle = profile?.accountType.label ?? 'Sin sesión';

              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onAccount,
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE7E9F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShellProfileAvatar(profile: profile, size: 36),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1D2130),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF697080),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShellProfileAvatar extends StatelessWidget {
  const _ShellProfileAvatar({required this.profile, required this.size});

  final OzirafProfile? profile;
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
          colors: [Color(0xFF7C4DFF), Color(0xFF45B8FF)],
        ),
      ),
      child: Text(
        profile?.initials ?? 'O',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final photo = profile?.profilePhoto.trim() ?? '';
    if (photo.isEmpty) return fallback;

    if (photo.startsWith('data:image/')) {
      try {
        final comma = photo.indexOf(',');
        if (comma < 0) return fallback;

        return ClipOval(
          child: Image.memory(
            base64Decode(photo.substring(comma + 1)),
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

class _MyPublicationsEnvironment extends StatefulWidget {
  const _MyPublicationsEnvironment({required this.onGoAccount});

  final VoidCallback onGoAccount;

  @override
  State<_MyPublicationsEnvironment> createState() =>
      _MyPublicationsEnvironmentState();
}

class _MyPublicationsEnvironmentState
    extends State<_MyPublicationsEnvironment> {
  int refreshKey = 0;

  Future<void> openPublish(OzirafProfile profile) async {
    await publish.openOzirafPublishSheet(context, profile);
    if (!mounted) return;
    setState(() => refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: OzirafSessionStore.tokenNotifier,
      builder: (context, token, _) {
        return ValueListenableBuilder<OzirafProfile?>(
          valueListenable: OzirafSessionStore.profileNotifier,
          builder: (context, profile, _) {
            if (token == null || token.trim().isEmpty || profile == null) {
              return _UtilityEnvironment(
                icon: Icons.lock_outline,
                title: 'Mis publicaciones',
                subtitle: 'Inicia sesión para ver solamente tus anuncios.',
                cards: [
                  _UtilityItem(
                    icon: Icons.person_outline,
                    title: 'Cuenta requerida',
                    text: 'Publicar y administrar anuncios necesita una sesión activa.',
                  ),
                ],
                actionLabel: 'Ir a Cuenta',
                onAction: widget.onGoAccount,
              );
            }

            return ColoredBox(
              color: const Color(0xFFF7F8FC),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF0EDFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: const Text(
                      'Mis publicaciones: aquí solo aparecen anuncios de tu cuenta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF513BD4),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: core.MyPostsScreen(
                      key: ValueKey(refreshKey),
                      token: token,
                      onEdit: (post) =>
                          publish.openOzirafEditPostSheet(context, post),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => openPublish(profile),
                          icon: const Icon(Icons.add_business_outlined),
                          label: const Text('Crear nueva publicación'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF654CFF),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MessagesEnvironment extends StatefulWidget {
  const _MessagesEnvironment({required this.token, required this.onGoAccount});

  final String? token;
  final VoidCallback onGoAccount;

  @override
  State<_MessagesEnvironment> createState() => _MessagesEnvironmentState();
}

class _MessagesEnvironmentState extends State<_MessagesEnvironment> {
  List<OzirafContactLead> received = const [];
  List<OzirafContactLead> sent = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _MessagesEnvironment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) load();
  }

  Future<void> load() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        OzirafSocialApi.fetchReceived(token),
        OzirafSocialApi.fetchSent(token),
      ]);
      if (!mounted) return;
      final nextReceived = values[0];
      setState(() {
        received = nextReceived;
        sent = values[1];
        loading = false;
      });
      SocialActionsStore.unreadLeadCount.value = nextReceived
          .where((lead) => lead.status == 'NEW')
          .length;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> updateStatus(OzirafContactLead lead, String status) async {
    final token = widget.token;
    if (token == null) return;
    try {
      await OzirafSocialApi.updateContactStatus(
        token: token,
        leadId: lead.id,
        status: status,
      );
      await load();
    } catch (e) {
      if (mounted) {
        _toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.trim().isEmpty) {
      return _UtilityEnvironment(
        icon: Icons.lock_outline,
        title: 'Mensajes',
        subtitle: 'Inicia sesión para ver solicitudes enviadas y recibidas.',
        cards: const [
          _UtilityItem(
            icon: Icons.chat_bubble_outline,
            title: 'Cuenta requerida',
            text: 'Los mensajes están ligados a tu cuenta OZIRAF.',
          ),
        ],
        actionLabel: 'Ir a Cuenta',
        onAction: widget.onGoAccount,
      );
    }

    return DefaultTabController(
      length: 2,
      child: _EnvironmentScaffold(
        icon: Icons.chat_bubble_outline,
        title: 'Mensajes',
        subtitle: 'Solicitudes reales enviadas y recibidas desde tus anuncios.',
        trailing: IconButton(
          tooltip: 'Actualizar mensajes',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Recibidos'),
                Tab(text: 'Enviados'),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? core.ErrorPanel(message: error!, onRetry: load)
                  : TabBarView(
                      children: [
                        _ContactLeadList(
                          leads: received,
                          received: true,
                          onStatus: updateStatus,
                        ),
                        _ContactLeadList(leads: sent, received: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedEnvironment extends StatefulWidget {
  const _SavedEnvironment({
    required this.token,
    required this.onGoAccount,
    required this.onOpenMessages,
  });

  final String? token;
  final VoidCallback onGoAccount;
  final VoidCallback onOpenMessages;

  @override
  State<_SavedEnvironment> createState() => _SavedEnvironmentState();
}

class _SavedEnvironmentState extends State<_SavedEnvironment> {
  List<core.ServicePost> posts = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant _SavedEnvironment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) load();
  }

  Future<void> load() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await OzirafSocialApi.fetchFavorites(token);
      if (!mounted) return;
      SocialActionsStore.savedPostIds.value = {
        for (final post in result) post.id,
      };
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
    if (widget.token == null || widget.token!.trim().isEmpty) {
      return _UtilityEnvironment(
        icon: Icons.lock_outline,
        title: 'Guardados',
        subtitle: 'Inicia sesión para conservar servicios entre dispositivos.',
        cards: const [
          _UtilityItem(
            icon: Icons.bookmark_border,
            title: 'Cuenta requerida',
            text: 'Tus favoritos se guardan en tu cuenta OZIRAF.',
          ),
        ],
        actionLabel: 'Ir a Cuenta',
        onAction: widget.onGoAccount,
      );
    }

    return _EnvironmentScaffold(
      icon: Icons.bookmark_border,
      title: 'Guardados',
      subtitle: 'Servicios que guardaste en tu cuenta.',
      trailing: IconButton(
        tooltip: 'Actualizar guardados',
        onPressed: loading ? null : load,
        icon: const Icon(Icons.refresh),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? core.ErrorPanel(message: error!, onRetry: load)
          : ValueListenableBuilder<Set<String>>(
              valueListenable: SocialActionsStore.savedPostIds,
              builder: (context, savedIds, _) {
                final visible = posts
                    .where((post) => savedIds.contains(post.id))
                    .toList();
                if (visible.isEmpty) {
                  return const core.PlaceholderPanel(
                    icon: Icons.bookmark_border,
                    title: 'Todavía no tienes guardados',
                    message:
                        'Pulsa el marcador de una publicación para verla aquí.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  children: [
                    for (final post in visible)
                      SocialServiceCard(
                        post: post,
                        onRequireAccount: widget.onGoAccount,
                        onOpenMessages: widget.onOpenMessages,
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _NotificationsEnvironment extends StatefulWidget {
  const _NotificationsEnvironment({
    required this.token,
    required this.onGoAccount,
    required this.onOpenMessages,
  });

  final String? token;
  final VoidCallback onGoAccount;
  final VoidCallback onOpenMessages;

  @override
  State<_NotificationsEnvironment> createState() =>
      _NotificationsEnvironmentState();
}

class _NotificationsEnvironmentState extends State<_NotificationsEnvironment> {
  List<OzirafContactLead> notifications = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = widget.token;
    if (token == null || token.trim().isEmpty) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await OzirafSocialApi.fetchReceived(token);
      final unread = result.where((lead) => lead.status == 'NEW').toList();
      if (!mounted) return;
      setState(() {
        notifications = unread;
        loading = false;
      });
      SocialActionsStore.unreadLeadCount.value = unread.length;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> markRead(OzirafContactLead lead) async {
    final token = widget.token;
    if (token == null) return;
    try {
      await OzirafSocialApi.updateContactStatus(
        token: token,
        leadId: lead.id,
        status: 'READ',
      );
      await load();
    } catch (e) {
      if (mounted) {
        _toast(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token == null || widget.token!.trim().isEmpty) {
      return _UtilityEnvironment(
        icon: Icons.notifications_none_rounded,
        title: 'Notificaciones',
        subtitle: 'Inicia sesión para ver novedades de tus anuncios.',
        cards: const [
          _UtilityItem(
            icon: Icons.lock_outline,
            title: 'Cuenta requerida',
            text: 'Las notificaciones pertenecen a tu cuenta OZIRAF.',
          ),
        ],
        actionLabel: 'Ir a Cuenta',
        onAction: widget.onGoAccount,
      );
    }

    return _EnvironmentScaffold(
      icon: Icons.notifications_none_rounded,
      title: 'Notificaciones',
      subtitle: 'Nuevas personas interesadas en tus publicaciones.',
      trailing: IconButton(
        tooltip: 'Actualizar notificaciones',
        onPressed: loading ? null : load,
        icon: const Icon(Icons.refresh),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? core.ErrorPanel(message: error!, onRetry: load)
          : notifications.isEmpty
          ? const core.PlaceholderPanel(
              icon: Icons.notifications_none_rounded,
              title: 'Estás al día',
              message: 'No tienes solicitudes nuevas.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final lead = notifications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0EDFF),
                      child: Icon(Icons.mark_email_unread_outlined),
                    ),
                    title: Text('${lead.personName} te contactó'),
                    subtitle: Text(
                      '${lead.post.title}\n${lead.message}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Marcar como leída',
                      onPressed: () => markRead(lead),
                      icon: const Icon(Icons.done),
                    ),
                    onTap: widget.onOpenMessages,
                  ),
                );
              },
            ),
    );
  }
}

class _EnvironmentScaffold extends StatelessWidget {
  const _EnvironmentScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F8FC),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE7E9F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF654CFF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF697080)),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ContactLeadList extends StatelessWidget {
  const _ContactLeadList({
    required this.leads,
    required this.received,
    this.onStatus,
  });

  final List<OzirafContactLead> leads;
  final bool received;
  final Future<void> Function(OzirafContactLead lead, String status)? onStatus;

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return core.PlaceholderPanel(
        icon: received ? Icons.inbox_outlined : Icons.outbox_outlined,
        title: received
            ? 'Sin solicitudes recibidas'
            : 'Sin solicitudes enviadas',
        message: received
            ? 'Cuando alguien contacte uno de tus anuncios aparecerá aquí.'
            : 'Las solicitudes que envíes desde Contactar aparecerán aquí.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: leads.length,
      itemBuilder: (context, index) {
        final lead = leads[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lead.post.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    _LeadStatusChip(status: lead.status),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  received
                      ? 'De: ${lead.personName}'
                      : 'Para: ${lead.personName}',
                  style: const TextStyle(color: Color(0xFF697080)),
                ),
                const SizedBox(height: 8),
                Text(lead.message),
                if (received && onStatus != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (lead.status == 'NEW')
                        TextButton.icon(
                          onPressed: () => onStatus!(lead, 'READ'),
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: const Text('Marcar leída'),
                        ),
                      TextButton.icon(
                        onPressed: () => onStatus!(lead, 'ARCHIVED'),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Archivar'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeadStatusChip extends StatelessWidget {
  const _LeadStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'READ' => 'Leída',
      'ARCHIVED' => 'Archivada',
      _ => 'Nueva',
    };
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _UtilityEnvironment extends StatelessWidget {
  const _UtilityEnvironment({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cards,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<_UtilityItem> cards;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;

    return ColoredBox(
      color: const Color(0xFFF7F8FC),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 36 : 16,
          desktop ? 28 : 16,
          desktop ? 36 : 16,
          110,
        ),
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 820),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7E9F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EDFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFF654CFF)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1D2130),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF697080),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...cards.map(
            (item) => Container(
              constraints: const BoxConstraints(maxWidth: 820),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE7E9F0)),
              ),
              child: Row(
                children: [
                  Icon(item.icon, color: const Color(0xFF654CFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.text,
                          style: const TextStyle(
                            color: Color(0xFF697080),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF654CFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UtilityItem {
  const _UtilityItem({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 39,
          height: compact ? 34 : 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFF45B8FF)],
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : 12),
          ),
          alignment: Alignment.center,
          child: Container(
            width: compact ? 12 : 14,
            height: compact ? 12 : 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Text(
          'OZIRAF',
          style: TextStyle(
            fontSize: compact ? 19 : 23,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            color: Color(0xFF1D2130),
          ),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({
    required this.selected,
    required this.isAdmin,
    required this.onSelected,
  });

  final int selected;
  final bool isAdmin;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Inicio', 0),
      (Icons.play_circle_outline, 'Shorts', 1),
      (Icons.add_circle_outline, 'Publicar', 2),
      (Icons.chat_bubble_outline, 'Mensajes', 3),
      (Icons.bookmark_border, 'Guardados', 5),
      (Icons.person_outline, 'Cuenta', 4),
      if (isAdmin) (Icons.admin_panel_settings_outlined, 'Admin', 7),
    ];

    return Container(
      width: 190,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: _BrandHeader(),
          ),
          const SizedBox(height: 30),
          ...List.generate(items.length, (itemIndex) {
            final shellIndex = items[itemIndex].$3;
            final active = shellIndex == selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                selected: active,
                selectedTileColor: const Color(0xFFF0EDFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Icon(
                  items[itemIndex].$1,
                  color: active
                      ? const Color(0xFF654CFF)
                      : const Color(0xFF555B69),
                ),
                title: Text(
                  items[itemIndex].$2,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active
                        ? const Color(0xFF654CFF)
                        : const Color(0xFF343846),
                  ),
                ),
                onTap: () => onSelected(shellIndex),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF4F1FF), Color(0xFFEEF8FF)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Eres profesional?',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 5),
                Text(
                  'Publica tus servicios y conecta con nuevos clientes.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6D7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
