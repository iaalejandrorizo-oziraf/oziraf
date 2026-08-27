import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_v2.dart' as core;
import 'auth_session.dart';
import 'oziraf_share.dart';
import 'post_video_dialog.dart';
import 'provider_profile.dart';
import 'social_api.dart';

const _purple = Color(0xFF654CFF);
const _purpleDark = Color(0xFF5135E8);
const _purpleSoft = Color(0xFFF0EDFF);
const _background = Color(0xFFF7F7FC);
const _border = Color(0xFFE8E8F1);
const _text = Color(0xFF191A22);
const _muted = Color(0xFF737787);

enum _FeedFilter { all, priced, media }

class SocialActionsStore {
  SocialActionsStore._();

  static final likedPostIds = ValueNotifier<Set<String>>(<String>{});
  static final savedPostIds = ValueNotifier<Set<String>>(<String>{});
  static final unreadLeadCount = ValueNotifier<int>(0);
  static final updatedPosts = ValueNotifier<Map<String, core.ServicePost>>(
    <String, core.ServicePost>{},
  );

  static core.ServicePost currentPost(core.ServicePost post) {
    return updatedPosts.value[post.id] ?? post;
  }

  static void applyReview(core.ServicePost post, OzirafReview review) {
    final current = currentPost(post);
    final updated = current.withSubmittedReview(
      core.ServiceReviewPreview(
        rating: review.rating,
        comment: review.comment,
        authorName: review.authorName,
        createdAt: DateTime.now(),
      ),
    );
    updatedPosts.value = {...updatedPosts.value, post.id: updated};
  }

  static void clearSessionData() {
    likedPostIds.value = <String>{};
    savedPostIds.value = <String>{};
    unreadLeadCount.value = 0;
  }
}

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({
    super.key,
    this.initialPostId,
    this.onPublish,
    this.onOpenSaved,
    this.onRequireAccount,
    this.onOpenMessages,
  });

  final String? initialPostId;
  final VoidCallback? onPublish;
  final VoidCallback? onOpenSaved;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final searchController = TextEditingController();

  List<core.ServicePost> posts = const [];
  bool loading = true;
  String? error;
  String selectedCategory = 'Todos';
  int topTab = 0;
  _FeedFilter activeFilter = _FeedFilter.all;
  bool sharedPostHandled = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await core.OzirafApiClient.fetchPosts();

      if (!mounted) return;

      setState(() {
        posts = result;
        loading = false;
      });
      await _openSharedPost(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        posts = const [];
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openSharedPost(List<core.ServicePost> loadedPosts) async {
    final postId = widget.initialPostId?.trim() ?? '';
    if (sharedPostHandled || postId.isEmpty) return;
    sharedPostHandled = true;

    core.ServicePost? post;
    for (final candidate in loadedPosts) {
      if (candidate.id == postId) {
        post = candidate;
        break;
      }
    }

    try {
      post ??= await core.OzirafApiClient.fetchPost(postId);
    } catch (_) {
      if (mounted) {
        _toast(context, 'Este anuncio ya no está disponible');
      }
      return;
    }
    if (!mounted) return;

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await showOzirafPostDetail(
      context,
      post,
      onRequireAccount: widget.onRequireAccount,
      onOpenMessages: widget.onOpenMessages,
    );
  }

  List<String> get categories {
    final values = <String>{};

    for (final post in posts) {
      final value = post.category.trim();

      if (value.isNotEmpty) {
        values.add(value);
      }

      if (values.length >= 7) break;
    }

    return ['Todos', ...values];
  }

  List<core.ServicePost> get filtered {
    final query = searchController.text.trim().toLowerCase();

    return posts.where((post) {
      final haystack =
          '${post.title} ${post.description} ${post.category} '
                  '${post.city} ${post.state}'
              .toLowerCase();

      final queryOk = query.isEmpty || haystack.contains(query);

      final categoryOk =
          selectedCategory == 'Todos' || post.category == selectedCategory;

      final filterOk = switch (activeFilter) {
        _FeedFilter.priced => !post.price.toLowerCase().contains('cotizar'),
        _FeedFilter.media => post.media.isNotEmpty,
        _FeedFilter.all => true,
      };

      final tabOk = switch (topTab) {
        1 => post.media.isNotEmpty,
        2 => _matchesProfileLocation(post),
        _ => true,
      };

      return queryOk && categoryOk && filterOk && tabOk;
    }).toList();
  }

  bool _matchesProfileLocation(core.ServicePost post) {
    final profile = OzirafSessionStore.profileNotifier.value;
    if (profile == null) return false;
    final city = profile.city.trim().toLowerCase();
    final state = profile.state.trim().toLowerCase();
    if (city.isNotEmpty && post.city.trim().toLowerCase() == city) return true;
    return state.isNotEmpty && post.state.trim().toLowerCase() == state;
  }

  void selectTopTab(int value) {
    if (value == 2) {
      final profile = OzirafSessionStore.profileNotifier.value;
      if (profile == null ||
          (profile.city.trim().isEmpty && profile.state.trim().isEmpty)) {
        _toast(context, 'Agrega tu ciudad en Cuenta para buscar cerca de ti');
        widget.onRequireAccount?.call();
        return;
      }
    }
    setState(() => topTab = value);
  }

  Future<void> openFilters() async {
    final selected = await _openFilterSheet(context, activeFilter);
    if (!mounted || selected == null) return;
    setState(() => activeFilter = selected);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;

        final feed = RefreshIndicator(
          onRefresh: load,
          color: _purple,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 0 : 11,
              11,
              desktop ? 0 : 11,
              108,
            ),
            children: [
              _TopTabs(selected: topTab, onChanged: selectTopTab),
              const SizedBox(height: 11),
              _SearchBox(
                controller: searchController,
                onChanged: () => setState(() {}),
                onFilters: openFilters,
                filtersActive: activeFilter != _FeedFilter.all,
              ),
              const SizedBox(height: 12),
              _CategoryStrip(
                categories: categories,
                selectedCategory: selectedCategory,
                onSelected: (category) {
                  setState(() => selectedCategory = category);
                },
              ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 70),
                  child: Center(
                    child: CircularProgressIndicator(color: _purple),
                  ),
                )
              else if (error != null)
                core.ErrorPanel(message: error!, onRetry: load)
              else if (filtered.isEmpty)
                const core.PlaceholderPanel(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados',
                  message: 'Prueba con otro servicio o categoría.',
                )
              else
                ...filtered.map(
                  (post) => SocialServiceCard(
                    post: post,
                    onRequireAccount: widget.onRequireAccount,
                    onOpenMessages: widget.onOpenMessages,
                  ),
                ),
            ],
          ),
        );

        if (!desktop) {
          return ColoredBox(color: _background, child: feed);
        }

        return ColoredBox(
          color: _background,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 730, child: feed),
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 265,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, right: 14),
                  child: _DesktopAside(
                    onPublish: widget.onPublish,
                    onOpenSaved: widget.onOpenSaved,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Servicios', 'Con fotos', 'Cerca de ti'];

    return Container(
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: active ? _purpleSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 0) ...[
                      Icon(
                        Icons.design_services_outlined,
                        size: 16,
                        color: active ? _purple : _muted,
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (index == 2) ...[
                      Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: active ? _purple : _muted,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        labels[index],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: active ? _purple : _text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onFilters,
    required this.filtersActive,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onFilters;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '¿Qué servicio necesitas?',
          hintStyle: const TextStyle(color: Color(0xFF888C99), fontSize: 14.5),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 24,
            color: Color(0xFF414451),
          ),
          suffixIcon: IconButton(
            tooltip: 'Filtros',
            onPressed: onFilters,
            icon: Icon(
              Icons.tune_rounded,
              size: 23,
              color: filtersActive ? _purple : const Color(0xFF414451),
            ),
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final controller = ScrollController();
  Timer? hoverTimer;
  bool canGoBack = false;
  bool canGoForward = true;

  @override
  void initState() {
    super.initState();
    controller.addListener(_updateControls);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateControls());
  }

  @override
  void didUpdateWidget(covariant _CategoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateControls());
  }

  @override
  void dispose() {
    hoverTimer?.cancel();
    controller
      ..removeListener(_updateControls)
      ..dispose();
    super.dispose();
  }

  void _updateControls() {
    if (!mounted || !controller.hasClients) return;
    final position = controller.position;
    final nextBack = position.pixels > position.minScrollExtent + 1;
    final nextForward = position.pixels < position.maxScrollExtent - 1;
    if (nextBack == canGoBack && nextForward == canGoForward) return;
    setState(() {
      canGoBack = nextBack;
      canGoForward = nextForward;
    });
  }

  Future<void> _moveBy(double distance) async {
    _stopHoverMove();
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + distance).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    await controller.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _startHoverMove(int direction) {
    hoverTimer?.cancel();
    hoverTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!controller.hasClients) return;
      final position = controller.position;
      final target = (position.pixels + direction * 1.6).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - position.pixels).abs() < .1) {
        _stopHoverMove();
        return;
      }
      controller.jumpTo(target.toDouble());
    });
  }

  void _stopHoverMove() {
    hoverTimer?.cancel();
    hoverTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          _CategoryArrow(
            tooltip: 'Categorías anteriores',
            icon: Icons.chevron_left_rounded,
            enabled: canGoBack,
            onPressed: () => _moveBy(-240),
            onHoverStart: () => _startHoverMove(-1),
            onHoverEnd: _stopHoverMove,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              controller: controller,
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: widget.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                final selected = category == widget.selectedCategory;

                return InkWell(
                  borderRadius: BorderRadius.circular(21),
                  onTap: () => widget.onSelected(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: selected ? _purpleSoft : Colors.white,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: selected ? const Color(0xFFD8CCFF) : _border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(category),
                          size: 16,
                          color: selected ? _purple : const Color(0xFF626673),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? _purple : const Color(0xFF3B3E49),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          _CategoryArrow(
            tooltip: 'Más categorías',
            icon: Icons.chevron_right_rounded,
            enabled: canGoForward,
            onPressed: () => _moveBy(240),
            onHoverStart: () => _startHoverMove(1),
            onHoverEnd: _stopHoverMove,
          ),
        ],
      ),
    );
  }
}

class _CategoryArrow extends StatelessWidget {
  const _CategoryArrow({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => onHoverStart() : null,
      onExit: (_) => onHoverEnd(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: _purple,
          disabledForegroundColor: const Color(0xFFB8BBC5),
          backgroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF4F4F8),
          side: BorderSide(color: enabled ? const Color(0xFFDCD4FF) : _border),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class SocialServiceCard extends StatelessWidget {
  const SocialServiceCard({
    super.key,
    required this.post,
    this.onRequireAccount,
    this.onOpenMessages,
  });

  final core.ServicePost post;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, core.ServicePost>>(
      valueListenable: SocialActionsStore.updatedPosts,
      builder: (context, updatedPosts, _) {
        return _buildCard(context, updatedPosts[post.id] ?? post);
      },
    );
  }

  Widget _buildCard(BuildContext context, core.ServicePost post) {
    final images = post.media.where((item) => item.isImage).toList();
    final videos = post.media.where((item) => item.isVideo).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 7, 10),
            child: _ProviderHeader(
              post: post,
              onRequireAccount: onRequireAccount,
              onOpenMessages: onOpenMessages,
            ),
          ),
          if (images.isNotEmpty)
            _SocialCarousel(images: images)
          else if (videos.isNotEmpty)
            _VideoPoster(post: post, video: videos.first)
          else
            _NoMediaPlaceholder(category: post.category, title: post.title),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 0),
            child: _PostInformation(post: post),
          ),
          if (images.isNotEmpty && videos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: SizedBox(
                width: double.infinity,
                height: 41,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showPostVideoDialog(
                      context,
                      url: videos.first.url,
                      title: post.title,
                      postId: post.id,
                      providerName: post.providerName,
                      description: post.description,
                      onReviewCreated: (review) =>
                          SocialActionsStore.applyReview(
                            post,
                            OzirafReview.fromJson(review),
                          ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text('Ver video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _purple,
                    side: const BorderSide(color: Color(0xFFDCD4FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _PostReviewStrip(
            post: post,
            onTap: () => _openCommentsSheet(
              context,
              post,
              onRequireAccount: onRequireAccount,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 1, 11, 10),
            child: _SocialActions(
              post: post,
              onRequireAccount: onRequireAccount,
              onOpenMessages: onOpenMessages,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostReviewStrip extends StatelessWidget {
  const _PostReviewStrip({required this.post, required this.onTap});

  final core.ServicePost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = post.latestReview;
    final count = post.reviewCount;
    final average = post.averageRating ?? 0;

    return Material(
      color: const Color(0xFFF8F7FC),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: Color(0xFFE9E7F0)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15, 10, 12, 10),
          child: count == 0
              ? const Row(
                  children: [
                    Icon(Icons.star_outline_rounded, color: _purple, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aún sin opiniones',
                            style: TextStyle(
                              color: _text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sé la primera persona en calificar este servicio.',
                            style: TextStyle(color: _muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _muted, size: 21),
                  ],
                )
              : preview == null
              ? Row(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ReviewStars(rating: average),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        count == 1 ? '1 opinión' : '$count opiniones',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _muted,
                      size: 21,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: _purpleSoft,
                      child: Text(
                        preview.authorName.trim().isEmpty
                            ? 'O'
                            : preview.authorName
                                  .trim()
                                  .substring(0, 1)
                                  .toUpperCase(),
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                average.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: _text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 5),
                              _ReviewStars(rating: average),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  count == 1 ? '1 opinión' : '$count opiniones',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _muted,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${preview.authorName}: ',
                                  style: const TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: preview.comment.trim().isEmpty
                                      ? 'Calificación sin comentario.'
                                      : preview.comment.trim(),
                                ),
                                TextSpan(
                                  text: '  ${preview.rating}.0 ★',
                                  style: const TextStyle(
                                    color: Color(0xFFB67A00),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF555968),
                              fontSize: 12,
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
    );
  }
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: index < filled
              ? const Color(0xFFF5B942)
              : const Color(0xFFC4C7CF),
          size: 14,
        ),
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({
    required this.post,
    this.onRequireAccount,
    this.onOpenMessages,
  });

  final core.ServicePost post;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => showOzirafProviderProfile(
              context,
              post,
              onContact: () => _openContactSheet(
                context,
                post,
                onRequireAccount: onRequireAccount,
                onOpenMessages: onOpenMessages,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  _SocialAvatar(
                    photo: post.providerPhoto,
                    name: post.providerName,
                    size: 47,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.providerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.15,
                                  color: _text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF4285F4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          post.providerProfession.trim().isEmpty
                              ? post.category
                              : post.providerProfession,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Color(0xFF858996),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${post.city}, ${post.state}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF858996),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _openPostOptions(
            context,
            post,
            onRequireAccount: onRequireAccount,
          ),
          icon: const Icon(Icons.more_horiz_rounded, size: 23),
        ),
      ],
    );
  }
}

class _PostInformation extends StatelessWidget {
  const _PostInformation({required this.post});

  final core.ServicePost post;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 430;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16.5,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      post.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PriceBadge(price: post.price),
                ],
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.42,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _PriceBadge(price: post.price),
          ],
        );
      },
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price});

  final String price;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _purpleSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Desde',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _purpleDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialActions extends StatelessWidget {
  const _SocialActions({
    required this.post,
    this.onRequireAccount,
    this.onOpenMessages,
  });

  final core.ServicePost post;
  final VoidCallback? onRequireAccount;
  final VoidCallback? onOpenMessages;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;

        return Row(
          children: [
            ValueListenableBuilder<Set<String>>(
              valueListenable: SocialActionsStore.likedPostIds,
              builder: (context, liked, _) {
                final active = liked.contains(post.id);
                return _RoundAction(
                  icon: active
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  tooltip: active ? 'Quitar me gusta' : 'Me gusta',
                  active: active,
                  onTap: () => _togglePost(
                    SocialActionsStore.likedPostIds,
                    post.id,
                    active ? 'Ya no te gusta' : 'Te gusta',
                    context,
                  ),
                );
              },
            ),
            _RoundAction(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Comentarios',
              onTap: () => _openCommentsSheet(
                context,
                post,
                onRequireAccount: onRequireAccount,
              ),
            ),
            _RoundAction(
              icon: Icons.send_outlined,
              tooltip: 'Compartir',
              onTap: () => shareOzirafPost(context, post),
            ),
            ValueListenableBuilder<Set<String>>(
              valueListenable: SocialActionsStore.savedPostIds,
              builder: (context, saved, _) {
                final active = saved.contains(post.id);
                return _RoundAction(
                  icon: active
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: active ? 'Quitar guardado' : 'Guardar',
                  active: active,
                  onTap: () => _setFavorite(
                    context,
                    post,
                    currentlySaved: active,
                    onRequireAccount: onRequireAccount,
                  ),
                );
              },
            ),
            const Spacer(),
            SizedBox(
              width: compact ? 126 : 160,
              height: 41,
              child: FilledButton.icon(
                onPressed: () {
                  _openContactSheet(
                    context,
                    post,
                    onRequireAccount: onRequireAccount,
                    onOpenMessages: onOpenMessages,
                  );
                },
                icon: const Icon(Icons.chat_outlined, size: 16),
                label: const Text('Contactar', overflow: TextOverflow.ellipsis),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 37, minHeight: 37),
        padding: const EdgeInsets.all(7),
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 21,
          color: active ? _purple : const Color(0xFF414451),
        ),
      ),
    );
  }
}

class _SocialCarousel extends StatefulWidget {
  const _SocialCarousel({required this.images});

  final List<core.PostMediaItem> images;

  @override
  State<_SocialCarousel> createState() => _SocialCarouselState();
}

class _SocialCarouselState extends State<_SocialCarousel> {
  late final PageController controller;
  int index = 0;

  @override
  void initState() {
    super.initState();
    controller = PageController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void go(int nextIndex) {
    if (!controller.hasClients ||
        nextIndex < 0 ||
        nextIndex >= widget.images.length) {
      return;
    }

    controller.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 700;
    final height = desktop ? 268.0 : 198.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: desktop ? 18 : 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(desktop ? 18 : 16),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.images.length,
                onPageChanged: (value) {
                  setState(() => index = value);
                },
                itemBuilder: (_, itemIndex) {
                  return Image.network(
                    widget.images[itemIndex].url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const ColoredBox(
                        color: Color(0xFFF0F2F7),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: _muted,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              if (widget.images.length > 1)
                Positioned(
                  top: 11,
                  right: 11,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .50),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (widget.images.length > 1 && index > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => go(index - 1),
                    ),
                  ),
                ),
              if (widget.images.length > 1 && index < widget.images.length - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _Arrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => go(index + 1),
                    ),
                  ),
                ),
              if (widget.images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.images.length, (dot) {
                      final active = dot == index;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active ? 17 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : Colors.white60,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoPoster extends StatelessWidget {
  const _VideoPoster({required this.post, required this.video});

  final core.ServicePost post;
  final core.PostMediaItem video;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 700;

    return InkWell(
      onTap: () {
        showPostVideoDialog(
          context,
          url: video.url,
          title: post.title,
          postId: post.id,
          providerName: post.providerName,
          description: post.description,
          onReviewCreated: (review) => SocialActionsStore.applyReview(
            post,
            OzirafReview.fromJson(review),
          ),
        );
      },
      child: Container(
        height: desktop ? 325 : 245,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF211D37), Color(0xFF563DE3), Color(0xFF875CFF)],
          ),
        ),
        child: Stack(
          children: [
            const Center(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 43,
                  color: Color(0xFF312846),
                ),
              ),
            ),
            Positioned(
              left: 13,
              bottom: 13,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Video',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMediaPlaceholder extends StatelessWidget {
  const _NoMediaPlaceholder({required this.category, required this.title});

  final String category;
  final String title;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 700;

    return Container(
      height: desktop ? 235 : 175,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0EBFF), Color(0xFFEAF7FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Icon(
              _categoryIcon(category),
              size: desktop ? 155 : 120,
              color: _purple.withValues(alpha: .08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: desktop ? 76 : 62,
                  height: desktop ? 76 : 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .86),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0C000000), blurRadius: 14),
                    ],
                  ),
                  child: Icon(
                    _categoryIcon(category),
                    size: desktop ? 39 : 32,
                    color: _purple,
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _purple,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: desktop ? 20 : 16,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Servicio disponible en OZIRAF',
                        style: TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .91),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 24, color: const Color(0xFF343640)),
        ),
      ),
    );
  }
}

class _SocialAvatar extends StatelessWidget {
  const _SocialAvatar({
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
          colors: [Color(0xFF8A3FFC), Color(0xFF2DB7FF)],
        ),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * .3,
        ),
      ),
    );

    Widget photoWidget = fallback;

    if (photo.startsWith('data:image/')) {
      try {
        final comma = photo.indexOf(',');

        if (comma >= 0) {
          photoWidget = Image.memory(
            base64Decode(photo.substring(comma + 1)),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        }
      } catch (_) {}
    } else if (photo.trim().isNotEmpty) {
      photoWidget = Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF7B3FFF), Color(0xFFEE5CA8), Color(0xFFFFB648)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: SizedBox(
            width: size - 7,
            height: size - 7,
            child: photoWidget,
          ),
        ),
      ),
    );
  }
}

class _DesktopAside extends StatelessWidget {
  const _DesktopAside({required this.onPublish, required this.onOpenSaved});

  final VoidCallback? onPublish;
  final VoidCallback? onOpenSaved;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _AsideCard(
          icon: Icons.rocket_launch_outlined,
          title: 'Publica tu servicio',
          text: 'Conecta con nuevos clientes dentro de OZIRAF.',
          action: 'Publicar ahora',
          onPressed: onPublish,
        ),
        const SizedBox(height: 12),
        _AsideCard(
          icon: Icons.bookmark_outline,
          title: 'Servicios guardados',
          text: 'Vuelve a los anuncios que marcaste como favoritos.',
          action: 'Ver guardados',
          onPressed: onOpenSaved,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorías populares',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 12),
              _PopularCategory(
                icon: Icons.home_repair_service_outlined,
                text: 'Hogar',
              ),
              _PopularCategory(icon: Icons.memory_outlined, text: 'Tecnología'),
              _PopularCategory(
                icon: Icons.self_improvement_outlined,
                text: 'Bienestar',
              ),
              _PopularCategory(
                icon: Icons.design_services_outlined,
                text: 'Diseño',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopularCategory extends StatelessWidget {
  const _PopularCategory({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _purpleSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: _purple),
          ),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF40434E),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsideCard extends StatelessWidget {
  const _AsideCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _purpleSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _purple, size: 23),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 37,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String value) {
  final text = value.toLowerCase();

  if (value == 'Todos') return Icons.grid_view_rounded;

  if (text.contains('yoga') || text.contains('bienestar')) {
    return Icons.self_improvement_outlined;
  }

  if (text.contains('electric')) {
    return Icons.electrical_services_outlined;
  }

  if (text.contains('constru') || text.contains('remodel')) {
    return Icons.home_repair_service_outlined;
  }

  if (text.contains('3d') || text.contains('impresi')) {
    return Icons.view_in_ar_outlined;
  }

  if (text.contains('limpieza')) {
    return Icons.cleaning_services_outlined;
  }

  if (text.contains('program') || text.contains('tecn')) {
    return Icons.memory_outlined;
  }

  if (text.contains('dise')) {
    return Icons.design_services_outlined;
  }

  if (text.contains('educ') || text.contains('clase')) {
    return Icons.school_outlined;
  }

  return Icons.category_outlined;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'O';

  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }

  return '${parts.first.substring(0, 1)}'
          '${parts.last.substring(0, 1)}'
      .toUpperCase();
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

void _togglePost(
  ValueNotifier<Set<String>> notifier,
  String postId,
  String message,
  BuildContext context,
) {
  final next = Set<String>.from(notifier.value);
  if (!next.add(postId)) next.remove(postId);
  notifier.value = next;
  _toast(context, message);
}

Future<void> _setFavorite(
  BuildContext context,
  core.ServicePost post, {
  required bool currentlySaved,
  VoidCallback? onRequireAccount,
}) async {
  final token = OzirafSessionStore.tokenNotifier.value;
  if (token == null || token.trim().isEmpty) {
    _toast(context, 'Inicia sesión para guardar servicios');
    onRequireAccount?.call();
    return;
  }

  try {
    if (currentlySaved) {
      await OzirafSocialApi.removeFavorite(token, post.id);
    } else {
      await OzirafSocialApi.saveFavorite(token, post.id);
    }
    final next = Set<String>.from(SocialActionsStore.savedPostIds.value);
    currentlySaved ? next.remove(post.id) : next.add(post.id);
    SocialActionsStore.savedPostIds.value = next;
    if (context.mounted) {
      _toast(context, currentlySaved ? 'Quitado de Guardados' : 'Guardado');
    }
  } catch (e) {
    if (context.mounted) {
      _toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }
}

Future<_FeedFilter?> _openFilterSheet(
  BuildContext context,
  _FeedFilter selected,
) {
  return showModalBottomSheet<_FeedFilter>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.filter_alt_off_outlined),
                title: const Text('Todos los servicios'),
                trailing: selected == _FeedFilter.all
                    ? const Icon(Icons.check, color: _purple)
                    : null,
                onTap: () => Navigator.pop(sheetContext, _FeedFilter.all),
              ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Precio visible'),
                subtitle: const Text('Solo servicios con precio publicado.'),
                trailing: selected == _FeedFilter.priced
                    ? const Icon(Icons.check, color: _purple)
                    : null,
                onTap: () => Navigator.pop(sheetContext, _FeedFilter.priced),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Con fotos o video'),
                subtitle: const Text(
                  'Solo publicaciones con contenido visual.',
                ),
                trailing: selected == _FeedFilter.media
                    ? const Icon(Icons.check, color: _purple)
                    : null,
                onTap: () => Navigator.pop(sheetContext, _FeedFilter.media),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openPostOptions(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Ver detalles'),
                subtitle: Text(post.title),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showOzirafPostDetail(
                    context,
                    post,
                    onRequireAccount: onRequireAccount,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border_rounded),
                title: const Text('Guardar servicio'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _setFavorite(
                    context,
                    post,
                    currentlySaved: SocialActionsStore.savedPostIds.value
                        .contains(post.id),
                    onRequireAccount: onRequireAccount,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Compartir'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  shareOzirafPost(context, post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Reportar publicación'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openReportSheet(
                    context,
                    post,
                    onRequireAccount: onRequireAccount,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showOzirafPostDetail(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
  VoidCallback? onOpenMessages,
}) async {
  final viewport = MediaQuery.sizeOf(context);
  final desktop = viewport.width >= 760;

  Widget content(BuildContext dialogContext) => Material(
    color: _background,
    borderRadius: BorderRadius.circular(desktop ? 12 : 0),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Container(
          height: 54,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, color: _purple, size: 21),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Anuncio OZIRAF',
                  style: TextStyle(
                    color: _text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded, color: _muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: SocialServiceCard(
              post: post,
              onRequireAccount: onRequireAccount,
              onOpenMessages: onOpenMessages,
            ),
          ),
        ),
      ],
    ),
  );

  if (desktop) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: SizedBox(
          width: 720,
          height: viewport.height.clamp(560, 860).toDouble(),
          child: content(dialogContext),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        SizedBox(height: viewport.height * .94, child: content(sheetContext)),
  );
}

Future<void> _openReportSheet(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
}) async {
  final token = OzirafSessionStore.tokenNotifier.value;
  if (token == null || token.trim().isEmpty) {
    _toast(context, 'Inicia sesión para reportar una publicación');
    onRequireAccount?.call();
    return;
  }

  var reason = 'SPAM';
  final details = TextEditingController();
  var sending = false;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              4,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reportar publicación',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SPAM',
                      child: Text('Contenido repetitivo'),
                    ),
                    DropdownMenuItem(
                      value: 'FRAUD',
                      child: Text('Posible fraude'),
                    ),
                    DropdownMenuItem(
                      value: 'INAPPROPRIATE',
                      child: Text('Contenido inapropiado'),
                    ),
                    DropdownMenuItem(
                      value: 'OTHER',
                      child: Text('Otro motivo'),
                    ),
                  ],
                  onChanged: sending
                      ? null
                      : (value) =>
                            setSheetState(() => reason = value ?? reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detalles opcionales',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sending
                        ? null
                        : () async {
                            setSheetState(() => sending = true);
                            try {
                              await OzirafSocialApi.reportPost(
                                token: token,
                                postId: post.id,
                                reason: reason,
                                details: details.text,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              if (context.mounted) {
                                _toast(context, 'Reporte enviado');
                              }
                            } catch (e) {
                              setSheetState(() => sending = false);
                              if (context.mounted) {
                                _toast(
                                  context,
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(sending ? 'Enviando...' : 'Enviar reporte'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    details.dispose();
  }
}

Future<void> _openContactSheet(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
  VoidCallback? onOpenMessages,
}) async {
  final token = OzirafSessionStore.tokenNotifier.value;
  if (token == null || token.trim().isEmpty) {
    _toast(context, 'Inicia sesión para contactar al anunciante');
    onRequireAccount?.call();
    return;
  }

  final messageController = TextEditingController(
    text: 'Hola, me interesa tu servicio: ${post.title}.',
  );
  var sending = false;
  String? errorMessage;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SocialAvatar(
                        photo: post.providerPhoto,
                        name: post.providerName,
                        size: 48,
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${post.category} · ${post.city}, ${post.state}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(post.description),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _purpleSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Precio: ${post.price}',
                      style: const TextStyle(
                        color: _purpleDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: messageController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje para ${post.providerName}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sending
                          ? null
                          : () async {
                              final message = messageController.text.trim();
                              if (message.length < 10) {
                                setSheetState(
                                  () => errorMessage = 'Escribe un mensaje de al menos 10 caracteres.',
                                );
                                return;
                              }
                              setSheetState(() {
                                sending = true;
                                errorMessage = null;
                              });
                              try {
                                await OzirafSocialApi.sendContact(
                                  token: token,
                                  postId: post.id,
                                  message: message,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                if (context.mounted) {
                                  _toast(context, 'Solicitud enviada');
                                }
                                onOpenMessages?.call();
                              } catch (e) {
                                setSheetState(() {
                                  sending = false;
                                  errorMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                });
                              }
                            },
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(sending ? 'Enviando...' : 'Enviar solicitud'),
                      style: FilledButton.styleFrom(backgroundColor: _purple),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  } finally {
    messageController.dispose();
  }
}

Future<void> _openCommentsSheet(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
}) async {
  final controller = TextEditingController();
  var rating = 5;
  var sending = false;
  String? errorMessage;
  List<OzirafReview> reviews = const [];
  try {
    reviews = await OzirafSocialApi.fetchReviews(post.id);
  } catch (e) {
    errorMessage = e.toString().replaceFirst('Exception: ', '');
  }
  if (!context.mounted) {
    controller.dispose();
    return;
  }

  String initials(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'O';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  Widget stars(int value, {double size = 15}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < value ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: index < value
              ? const Color(0xFFF5B942)
              : const Color(0xFFB7BBC6),
        ),
      ),
    );
  }

  final countLabel = reviews.length == 1
      ? '1 opinión'
      : '${reviews.length} opiniones';
  final averageRating = reviews.isEmpty
      ? 0.0
      : reviews.fold<int>(0, (sum, review) => sum + review.rating) /
            reviews.length;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .32),
    constraints: const BoxConstraints(maxWidth: 430),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          final viewport = MediaQuery.sizeOf(context);
          final desktopLayout = viewport.width >= 700;
          final floatingInset = desktopLayout ? 24.0 : 0.0;
          final availableHeight = viewport.height - bottom - floatingInset - 12;
          final maximumHeight = availableHeight.clamp(360.0, double.infinity);
          final preferredHeight = desktopLayout
              ? 330.0 + (reviews.length.clamp(0, 3) * 25)
              : viewport.height * .74;
          final height = preferredHeight.clamp(360.0, maximumHeight).toDouble();
          final panelRadius = desktopLayout
              ? BorderRadius.circular(8)
              : const BorderRadius.vertical(top: Radius.circular(8));

          return Padding(
            padding: EdgeInsets.only(bottom: bottom + floatingInset),
            child: Material(
              color: Colors.transparent,
              elevation: desktopLayout ? 18 : 0,
              shadowColor: Colors.black.withValues(alpha: .18),
              clipBehavior: Clip.antiAlias,
              borderRadius: panelRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xB3FFFFFF),
                    borderRadius: panelRadius,
                    border: Border.all(color: const Color(0x99FFFFFF)),
                  ),
                  child: SizedBox(
                    height: height,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 60,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: _purpleSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.forum_outlined,
                                    color: _purple,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Comentarios',
                                        style: TextStyle(
                                          color: _text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${averageRating.toStringAsFixed(1)} ★ · $countLabel · ${post.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Cerrar',
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: _border),
                        Expanded(
                          child: reviews.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircleAvatar(
                                          radius: 26,
                                          backgroundColor: _purpleSoft,
                                          child: Icon(
                                            Icons.forum_outlined,
                                            color: _purple,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 11),
                                        Text(
                                          errorMessage == null
                                              ? 'Inicia la conversación'
                                              : 'No pudimos cargar las opiniones',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: _text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          errorMessage ?? 'Sé la primera persona en dejar una opinión.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: errorMessage == null
                                                ? _muted
                                                : const Color(0xFFB42318),
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: reviews.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    indent: 60,
                                    endIndent: 16,
                                    color: _border,
                                  ),
                                  itemBuilder: (context, index) {
                                    final review = reviews[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: _purpleSoft,
                                            child: Text(
                                              initials(review.authorName),
                                              style: const TextStyle(
                                                color: _purple,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  review.authorName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _text,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    stars(review.rating),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      review.rating
                                                          .toStringAsFixed(1),
                                                      style: const TextStyle(
                                                        color: _muted,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (review
                                                    .comment
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    review.comment,
                                                    style: const TextStyle(
                                                      color: Color(0xFF414654),
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xBDF9F9FC),
                            border: Border(top: BorderSide(color: _border)),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 11),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (errorMessage != null && reviews.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Color(0xFFB42318),
                                        size: 17,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          errorMessage!,
                                          style: const TextStyle(
                                            color: Color(0xFFB42318),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  const Text(
                                    'Tu valoración',
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  ...List.generate(5, (index) {
                                    final value = index + 1;
                                    return SizedBox.square(
                                      dimension: 28,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        tooltip:
                                            '$value ${value == 1 ? 'estrella' : 'estrellas'}',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: sending
                                            ? null
                                            : () => setSheetState(
                                                () => rating = value,
                                              ),
                                        icon: Icon(
                                          value <= rating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: value <= rating
                                              ? const Color(0xFFF5B942)
                                              : const Color(0xFFB7BBC6),
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      maxLength: 500,
                                      minLines: 1,
                                      maxLines: 3,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Escribe un comentario...',
                                        hintStyle: const TextStyle(
                                          color: _muted,
                                        ),
                                        counterText: '',
                                        filled: true,
                                        fillColor: const Color(0xD1FFFFFF),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _border,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _purple,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  SizedBox.square(
                                    dimension: 42,
                                    child: IconButton.filled(
                                      tooltip: 'Publicar comentario',
                                      style: IconButton.styleFrom(
                                        backgroundColor: _purple,
                                        disabledBackgroundColor: const Color(
                                          0xFFD6D2EA,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: sending
                                          ? null
                                          : () async {
                                              final token = OzirafSessionStore
                                                  .tokenNotifier
                                                  .value;
                                              if (token == null ||
                                                  token.trim().isEmpty) {
                                                Navigator.pop(sheetContext);
                                                _toast(
                                                  context,
                                                  'Inicia sesión para publicar una opinión',
                                                );
                                                onRequireAccount?.call();
                                                return;
                                              }
                                              setSheetState(() {
                                                sending = true;
                                                errorMessage = null;
                                              });
                                              try {
                                                final createdReview =
                                                    await OzirafSocialApi.createReview(
                                                      token: token,
                                                      postId: post.id,
                                                      rating: rating,
                                                      comment: controller.text,
                                                    );
                                                SocialActionsStore.applyReview(
                                                  post,
                                                  createdReview,
                                                );
                                                if (sheetContext.mounted) {
                                                  Navigator.pop(sheetContext);
                                                }
                                                if (context.mounted) {
                                                  _toast(
                                                    context,
                                                    'Opinión publicada',
                                                  );
                                                }
                                              } catch (e) {
                                                setSheetState(() {
                                                  sending = false;
                                                  errorMessage = e
                                                      .toString()
                                                      .replaceFirst(
                                                        'Exception: ',
                                                        '',
                                                      );
                                                });
                                              }
                                            },
                                      icon: sending
                                          ? const SizedBox.square(
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.send_rounded,
                                              size: 21,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  controller.dispose();
}

void toggleOzirafLike(BuildContext context, core.ServicePost post) {
  final active = SocialActionsStore.likedPostIds.value.contains(post.id);
  _togglePost(
    SocialActionsStore.likedPostIds,
    post.id,
    active ? 'Ya no te gusta' : 'Te gusta',
    context,
  );
}

Future<void> toggleOzirafFavorite(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
}) {
  return _setFavorite(
    context,
    post,
    currentlySaved: SocialActionsStore.savedPostIds.value.contains(post.id),
    onRequireAccount: onRequireAccount,
  );
}

Future<void> shareOzirafPost(BuildContext context, core.ServicePost post) {
  return showOzirafShareSheet(
    context,
    title: post.title,
    description: post.description,
    location: '${post.city}, ${post.state}',
    price: post.price,
    postId: post.id,
  );
}

Future<void> openOzirafComments(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
}) {
  return _openCommentsSheet(context, post, onRequireAccount: onRequireAccount);
}

Future<void> openOzirafContact(
  BuildContext context,
  core.ServicePost post, {
  VoidCallback? onRequireAccount,
  VoidCallback? onOpenMessages,
}) {
  return _openContactSheet(
    context,
    post,
    onRequireAccount: onRequireAccount,
    onOpenMessages: onOpenMessages,
  );
}
