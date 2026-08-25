import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oziraf/app_v2.dart';
import 'package:oziraf/app_v4.dart' as profile_editor;
import 'package:oziraf/auth_session.dart';
import 'package:oziraf/post_video_dialog.dart';
import 'package:oziraf/shorts_feed.dart';
import 'package:oziraf/social_feed.dart';

void main() {
  testWidgets('renders OZIRAF branding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: OzirafMark(size: 64))),
      ),
    );

    expect(find.byType(OzirafMark), findsOneWidget);
  });

  testWidgets('owned publication exposes edit action', (tester) async {
    var edited = false;
    const post = ServicePost(
      id: 'post-1',
      title: 'Servicio de prueba',
      description: 'Descripción del servicio',
      category: 'Hogar',
      city: 'Guadalajara',
      state: 'Jalisco',
      price: r'$500',
      providerName: 'Usuario OZIRAF',
      providerPhoto: '',
      media: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceCard(
              post: post,
              owned: true,
              onEdit: () => edited = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Editar publicación'), findsOneWidget);
    await tester.tap(find.text('Editar publicación'));
    expect(edited, isTrue);
  });

  testWidgets('profile editor exposes the social network selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const profile = OzirafProfile(
      id: 'user-1',
      email: 'usuario@oziraf.test',
      firstName: 'Usuario',
      lastName: 'OZIRAF',
      city: 'Xalapa',
      state: 'Veracruz',
      profession: 'Remodelaciones',
      phone: '',
      accountType: OzirafAccountType.anunciante,
      tiktokUrl: 'https://tiktok.com/@oziraf',
      xUrl: 'https://x.com/oziraf',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  profile_editor.showOzirafEditProfileDialog(context, profile),
              child: const Text('Abrir perfil'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Redes sociales'), findsOneWidget);
    expect(find.text('Seleccionar red'), findsOneWidget);
    expect(find.byTooltip('Agregar red social'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
  });

  testWidgets('share menu exposes every supported social network', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const post = ServicePost(
      id: 'post-1',
      title: 'Remodelaciones',
      description: 'Servicio de prueba',
      category: 'Hogar',
      city: 'Xalapa',
      state: 'Veracruz',
      price: r'$500',
      providerName: 'Usuario OZIRAF',
      providerPhoto: '',
      media: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: IconButton(
              tooltip: 'Compartir prueba',
              onPressed: () => shareOzirafPost(context, post),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Compartir prueba'));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('X'), findsNWidgets(2));
    expect(find.text('Más opciones'), findsOneWidget);
  });

  test('profile reads TikTok and X links from the server', () {
    final profile = OzirafProfile.fromJson({
      'id': 'user-1',
      'email': 'usuario@oziraf.test',
      'firstName': 'Usuario',
      'accountType': 'ANUNCIANTE',
      'tiktokUrl': 'https://tiktok.com/@oziraf',
      'xUrl': 'https://x.com/oziraf',
    });

    expect(profile.tiktokUrl, 'https://tiktok.com/@oziraf');
    expect(profile.xUrl, 'https://x.com/oziraf');
  });

  test('post reads its rating summary and latest review from the server', () {
    final post = ServicePost.fromJson({
      'id': 'post-1',
      'title': 'Remodelaciones',
      'description': 'Servicio de prueba',
      'category': 'Hogar',
      'city': 'Xalapa',
      'state': 'Veracruz',
      'price': 500,
      'averageRating': 4.5,
      'reviewCount': 2,
      'user': {'firstName': 'Ana', 'lastName': 'López'},
      'media': <Object>[],
      'latestReview': {
        'rating': 5,
        'comment': 'Excelente servicio',
        'createdAt': '2026-08-24T12:00:00.000Z',
        'author': {'firstName': 'Cliente', 'lastName': 'Uno'},
      },
    });

    expect(post.averageRating, 4.5);
    expect(post.reviewCount, 2);
    expect(post.latestReview?.authorName, 'Cliente Uno');
    expect(post.latestReview?.rating, 5);
    expect(post.latestReview?.comment, 'Excelente servicio');
  });

  testWidgets('service ad shows rating, opinion count and latest comment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const post = ServicePost(
      id: 'post-1',
      title: 'Remodelaciones',
      description: 'Servicio de prueba',
      category: 'Hogar',
      city: 'Xalapa',
      state: 'Veracruz',
      price: r'$500',
      providerName: 'Usuario OZIRAF',
      providerPhoto: '',
      media: [],
      averageRating: 4.5,
      reviewCount: 2,
      latestReview: ServiceReviewPreview(
        rating: 5,
        comment: 'Excelente servicio',
        authorName: 'Cliente Uno',
        createdAt: null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SocialServiceCard(post: post)),
        ),
      ),
    );

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('2 opiniones'), findsOneWidget);
    expect(find.textContaining('Cliente Uno'), findsOneWidget);
    expect(find.textContaining('Excelente servicio'), findsOneWidget);
  });

  testWidgets('web video player stays embedded inside the OZIRAF page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => buildOzirafVideoDialogFrame(
            context,
            embedded: true,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('oziraf-embedded-video-frame')),
    );
    expect(size.width, lessThan(500));
    expect(size.width / size.height, closeTo(9 / 16, .01));
    expect(size.height, lessThan(800));
  });

  test('web Shorts frame stays vertical and compact', () {
    final desktop = resolveOzirafShortFrame(const Size(1100, 850));
    final compact = resolveOzirafShortFrame(const Size(760, 600));

    expect(desktop.width / desktop.height, closeTo(9 / 16, .001));
    expect(desktop.width, lessThan(500));
    expect(desktop.height, lessThanOrEqualTo(780));
    expect(compact.width / compact.height, closeTo(9 / 16, .001));
    expect(compact.height, lessThan(600));
  });

  test('video query version never leaks into API routes', () {
    final base = resolveOzirafApiBase(
      'http://127.0.0.1:3001/posts/media/media-1?v=2',
    );

    expect(base, 'http://127.0.0.1:3001');
    expect(
      '$base/reviews/posts/post-1',
      'http://127.0.0.1:3001/reviews/posts/post-1',
    );
  });
}
