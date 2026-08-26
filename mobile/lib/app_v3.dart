import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_v2.dart' as legacy;
import 'auth_session.dart';
import 'provider_profile.dart';

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
      var restoredProfile = await legacy.OzirafApiClient.fetchProfile(
        savedToken,
      );
      final storedType = await sessionStore.readAccountType();
      if (storedType != null) {
        restoredProfile = restoredProfile.copyWith(accountType: storedType);
      } else {
        final mine = await legacy.OzirafApiClient.fetchMyPosts(savedToken);
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
    var loadedProfile = await legacy.OzirafApiClient.fetchProfile(accessToken);
    final mine = await legacy.OzirafApiClient.fetchMyPosts(accessToken);
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
          seedColor: legacy.OzirafColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: legacy.OzirafColors.background,
      ),
      home: restoring
          ? const _LoadingScreen()
          : _HomeShell(
              token: token,
              profile: profile,
              onLogin: onLogin,
              onLogout: logout,
              onAccountTypeChanged: changeAccountType,
            ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            legacy.OzirafMark(size: 66),
            SizedBox(height: 18),
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Recuperando tu sesión...'),
          ],
        ),
      ),
    );
  }
}

enum _Tab { buscar, actividad, solicitudes, publicar, cuenta }

class _HomeShell extends StatefulWidget {
  const _HomeShell({
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
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  _Tab tab = _Tab.buscar;

  bool get isAdvertiser =>
      widget.profile?.accountType == OzirafAccountType.anunciante;

  List<_Tab> get tabs => isAdvertiser
      ? const [
          _Tab.buscar,
          _Tab.actividad,
          _Tab.solicitudes,
          _Tab.publicar,
          _Tab.cuenta,
        ]
      : const [_Tab.buscar, _Tab.actividad, _Tab.solicitudes, _Tab.cuenta];

  void goHome() => setState(() => tab = _Tab.buscar);

  @override
  void didUpdateWidget(covariant _HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!tabs.contains(tab)) tab = _Tab.buscar;
  }

  @override
  Widget build(BuildContext context) {
    final activeTabs = tabs;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: legacy.OzirafColors.surface,
        surfaceTintColor: legacy.OzirafColors.surface,
        leading: tab == _Tab.buscar
            ? null
            : IconButton(
                tooltip: 'Volver a inicio',
                onPressed: goHome,
                icon: const Icon(Icons.arrow_back),
              ),
        title: const Row(
          children: [
            legacy.OzirafMark(size: 38),
            SizedBox(width: 10),
            Text('OZIRAF', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          if (widget.profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(label: Text(widget.profile!.accountType.label)),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeTabs.indexOf(tab),
        onDestinationSelected: (index) =>
            setState(() => tab = activeTabs[index]),
        destinations: activeTabs
            .map(
              (item) => NavigationDestination(
                icon: Icon(_icon(item, false)),
                selectedIcon: Icon(_icon(item, true)),
                label: _label(item),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _body() {
    switch (tab) {
      case _Tab.buscar:
        return const legacy.SearchScreen();
      case _Tab.actividad:
        if (widget.token == null) {
          return const legacy.LoginRequiredPanel(
            title: 'Tu actividad',
            message:
                'Inicia sesión para ver favoritos o administrar tus anuncios.',
          );
        }
        return isAdvertiser
            ? legacy.MyPostsScreen(token: widget.token!)
            : const legacy.PlaceholderPanel(
                icon: Icons.favorite_border,
                title: 'Favoritos',
                message: 'Aquí aparecerán los servicios que guardes.',
              );
      case _Tab.solicitudes:
        return widget.token == null
            ? const legacy.LoginRequiredPanel(
                title: 'Solicitudes',
                message: 'Inicia sesión para consultar tus solicitudes.',
              )
            : legacy.PlaceholderPanel(
                icon: Icons.chat_bubble_outline,
                title: isAdvertiser
                    ? 'Solicitudes recibidas'
                    : 'Mis solicitudes',
                message: isAdvertiser
                    ? 'Aquí aparecerán las personas interesadas en tus anuncios.'
                    : 'Aquí podrás dar seguimiento a tus solicitudes.',
              );
      case _Tab.publicar:
        return const legacy.PlaceholderPanel(
          icon: Icons.add_business_outlined,
          title: 'Publicar servicio',
          message: 'Tu cuenta está en modo Anunciante. El formulario de publicación será el siguiente bloque.',
        );
      case _Tab.cuenta:
        return _AccountScreen(
          token: widget.token,
          profile: widget.profile,
          onLogin: widget.onLogin,
          onLogout: widget.onLogout,
          onAccountTypeChanged: widget.onAccountTypeChanged,
          onGoHome: goHome,
        );
    }
  }

  String _label(_Tab item) {
    switch (item) {
      case _Tab.buscar:
        return 'Buscar';
      case _Tab.actividad:
        return isAdvertiser ? 'Mis anuncios' : 'Favoritos';
      case _Tab.solicitudes:
        return 'Solicitudes';
      case _Tab.publicar:
        return 'Publicar';
      case _Tab.cuenta:
        return 'Cuenta';
    }
  }

  IconData _icon(_Tab item, bool selected) {
    switch (item) {
      case _Tab.buscar:
        return selected ? Icons.search : Icons.search_outlined;
      case _Tab.actividad:
        return selected ? Icons.dashboard : Icons.dashboard_outlined;
      case _Tab.solicitudes:
        return selected ? Icons.chat_bubble : Icons.chat_bubble_outline;
      case _Tab.publicar:
        return selected ? Icons.add_circle : Icons.add_circle_outline;
      case _Tab.cuenta:
        return selected ? Icons.person : Icons.person_outline;
    }
  }
}

enum _AccountMode { login, register, recovery }

class OzirafAccountScreen extends StatelessWidget {
  const OzirafAccountScreen({
    super.key,
    required this.token,
    required this.profile,
    required this.onLogin,
    required this.onLogout,
    required this.onAccountTypeChanged,
    required this.onGoHome,
    this.onEditProfile,
  });

  final String? token;
  final OzirafProfile? profile;
  final Future<void> Function(String token) onLogin;
  final Future<void> Function() onLogout;
  final Future<void> Function(OzirafAccountType type) onAccountTypeChanged;
  final VoidCallback onGoHome;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _AccountScreen(
      token: token,
      profile: profile,
      onLogin: onLogin,
      onLogout: onLogout,
      onAccountTypeChanged: onAccountTypeChanged,
      onGoHome: onGoHome,
      onEditProfile: onEditProfile,
    );
  }
}

class _AccountScreen extends StatefulWidget {
  const _AccountScreen({
    required this.token,
    required this.profile,
    required this.onLogin,
    required this.onLogout,
    required this.onAccountTypeChanged,
    required this.onGoHome,
    this.onEditProfile,
  });

  final String? token;
  final OzirafProfile? profile;
  final Future<void> Function(String token) onLogin;
  final Future<void> Function() onLogout;
  final Future<void> Function(OzirafAccountType type) onAccountTypeChanged;
  final VoidCallback onGoHome;
  final VoidCallback? onEditProfile;

  @override
  State<_AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<_AccountScreen> {
  final loginKey = GlobalKey<FormState>();
  final registerKey = GlobalKey<FormState>();
  final recoveryKey = GlobalKey<FormState>();

  final email = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final registerEmail = TextEditingController();
  final registerPassword = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final recoveryEmail = TextEditingController();
  final recoveryToken = TextEditingController();
  final recoveryPassword = TextEditingController();

  _AccountMode mode = _AccountMode.login;
  OzirafAccountType newAccountType = OzirafAccountType.solicitante;
  bool busy = false;
  bool showRecoveryCode = false;
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
    recoveryEmail.dispose();
    recoveryToken.dispose();
    recoveryPassword.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!loginKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final accessToken = await legacy.OzirafApiClient.login(
        email: email.text,
        password: password.text,
      );
      await widget.onLogin(accessToken);
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
      await legacy.OzirafApiClient.register(
        firstName: firstName.text,
        lastName: lastName.text,
        email: registerEmail.text,
        password: registerPassword.text,
        city: city.text,
        state: state.text,
      );
      final accessToken = await legacy.OzirafApiClient.login(
        email: registerEmail.text,
        password: registerPassword.text,
      );
      await widget.onLogin(accessToken);
      await widget.onAccountTypeChanged(newAccountType);
      if (!mounted) return;
      registerPassword.clear();
      setState(() {
        busy = false;
        mode = _AccountMode.login;
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

  Future<void> requestRecovery() async {
    if (!recoveryKey.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await _PasswordRecoveryApi.request(recoveryEmail.text);
      if (!mounted) return;
      setState(() {
        busy = false;
        showRecoveryCode = true;
        message = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> confirmRecovery() async {
    if (recoveryToken.text.trim().isEmpty ||
        recoveryPassword.text.length < 8 ||
        busy) {
      setState(
        () => message =
            'Escribe el código y una contraseña de al menos 8 caracteres.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await _PasswordRecoveryApi.confirm(
        token: recoveryToken.text,
        newPassword: recoveryPassword.text,
      );
      if (!mounted) return;
      recoveryPassword.clear();
      recoveryToken.clear();
      setState(() {
        busy = false;
        showRecoveryCode = false;
        mode = _AccountMode.login;
        message = 'Contraseña actualizada. Ya puedes iniciar sesión.';
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
          _HomeButton(onPressed: widget.onGoHome),
          const SizedBox(height: 14),
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
                  Text(profile.email),
                  if (profile.city.isNotEmpty || profile.state.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${profile.city}${profile.city.isNotEmpty && profile.state.isNotEmpty ? ', ' : ''}${profile.state}',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Chip(label: Text(profile.accountType.label)),
                  if (profile.hasSocialLinks) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (profile.whatsapp.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('WhatsApp'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.whatsapp,
                              OzirafSocialNetwork.whatsapp,
                            ),
                          ),
                        if (profile.instagramUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Instagram'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.instagramUrl,
                              OzirafSocialNetwork.instagram,
                            ),
                          ),
                        if (profile.facebookUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.facebook_outlined,
                              size: 18,
                            ),
                            label: const Text('Facebook'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.facebookUrl,
                              OzirafSocialNetwork.facebook,
                            ),
                          ),
                        if (profile.tiktokUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.music_note_outlined,
                              size: 18,
                            ),
                            label: const Text('TikTok'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.tiktokUrl,
                              OzirafSocialNetwork.tiktok,
                            ),
                          ),
                        if (profile.xUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.alternate_email_outlined,
                              size: 18,
                            ),
                            label: const Text('X'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.xUrl,
                              OzirafSocialNetwork.x,
                            ),
                          ),
                        if (profile.websiteUrl.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(
                              Icons.language_outlined,
                              size: 18,
                            ),
                            label: const Text('Sitio web'),
                            onPressed: () => openOzirafSocialLink(
                              context,
                              profile.websiteUrl,
                              OzirafSocialNetwork.website,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (widget.onEditProfile != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: widget.onEditProfile,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil, foto y redes'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Usar OZIRAF como',
            style: TextStyle(fontWeight: FontWeight.w900),
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
        _HomeButton(onPressed: widget.onGoHome),
        const SizedBox(height: 16),
        if (mode == _AccountMode.login) _buildLogin(context),
        if (mode == _AccountMode.register) _buildRegister(context),
        if (mode == _AccountMode.recovery) _buildRecovery(context),
        if (message != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogin(BuildContext context) {
    return Form(
      key: loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Iniciar sesión',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu sesión quedará guardada de forma segura en este dispositivo.',
          ),
          const SizedBox(height: 16),
          legacy.OzirafField(
            controller: email,
            label: 'Correo',
            icon: Icons.email_outlined,
            validator: legacy.emailValidator,
          ),
          legacy.OzirafField(
            controller: password,
            label: 'Contraseña',
            icon: Icons.lock_outline,
            obscure: true,
            validator: legacy.passwordValidator,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : login,
              icon: const Icon(Icons.login),
              label: Text(busy ? 'Entrando...' : 'Entrar'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      mode = _AccountMode.recovery;
                      recoveryEmail.text = email.text;
                      message = null;
                    }),
              child: const Text('Olvidé mi contraseña'),
            ),
          ),
          Center(
            child: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      mode = _AccountMode.register;
                      message = null;
                    }),
              child: const Text('Crear una cuenta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegister(BuildContext context) {
    return Form(
      key: registerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crear cuenta',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
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
          legacy.OzirafField(
            controller: firstName,
            label: 'Nombre',
            icon: Icons.person_outline,
            validator: legacy.requiredValidator,
          ),
          legacy.OzirafField(
            controller: lastName,
            label: 'Apellido',
            icon: Icons.badge_outlined,
          ),
          legacy.OzirafField(
            controller: registerEmail,
            label: 'Correo',
            icon: Icons.email_outlined,
            validator: legacy.emailValidator,
          ),
          legacy.OzirafField(
            controller: registerPassword,
            label: 'Contraseña',
            icon: Icons.lock_outline,
            obscure: true,
            validator: legacy.passwordValidator,
          ),
          legacy.OzirafField(
            controller: city,
            label: 'Ciudad',
            icon: Icons.location_city_outlined,
          ),
          legacy.OzirafField(
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
          Center(
            child: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      mode = _AccountMode.login;
                      message = null;
                    }),
              child: const Text('Ya tengo cuenta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecovery(BuildContext context) {
    return Form(
      key: recoveryKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recuperar contraseña',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Solicita un código de recuperación. Por seguridad, OZIRAF nunca mostrará ese código dentro de la app.',
          ),
          const SizedBox(height: 16),
          legacy.OzirafField(
            controller: recoveryEmail,
            label: 'Correo de tu cuenta',
            icon: Icons.email_outlined,
            validator: legacy.emailValidator,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : requestRecovery,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(busy ? 'Solicitando...' : 'Solicitar recuperación'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() => showRecoveryCode = !showRecoveryCode),
            child: Text(
              showRecoveryCode ? 'Ocultar código' : 'Ya tengo un código',
            ),
          ),
          if (showRecoveryCode) ...[
            const SizedBox(height: 8),
            legacy.OzirafField(
              controller: recoveryToken,
              label: 'Código de recuperación',
              icon: Icons.key_outlined,
            ),
            legacy.OzirafField(
              controller: recoveryPassword,
              label: 'Nueva contraseña',
              icon: Icons.lock_reset_outlined,
              obscure: true,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : confirmRecovery,
                icon: const Icon(Icons.password),
                label: const Text('Cambiar contraseña'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      mode = _AccountMode.login;
                      message = null;
                    }),
              child: const Text('Volver a iniciar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.home_outlined),
        label: const Text('Volver a Inicio'),
      ),
    );
  }
}

class _PasswordRecoveryApi {
  static Future<String> request(String email) async {
    final response = await http
        .post(
          Uri.parse(
            '${legacy.OzirafApiClient.baseUrl}/auth/password-reset/request',
          ),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 10));
    final payload = _decode(response.body);
    _ensureSuccess(response.statusCode, payload);
    if (payload is Map<String, dynamic>) {
      final value = payload['message'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'Solicitud recibida.';
  }

  static Future<void> confirm({
    required String token,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse(
            '${legacy.OzirafApiClient.baseUrl}/auth/password-reset/confirm',
          ),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token.trim(), 'newPassword': newPassword}),
        )
        .timeout(const Duration(seconds: 10));
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
}
