import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_v2.dart' as core;

class OzirafAdminUser {
  const OzirafAdminUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    required this.accountType,
    required this.billingStatus,
    required this.renewalDueAt,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String status;
  final String accountType;
  final String billingStatus;
  final DateTime? renewalDueAt;
  final DateTime? createdAt;

  factory OzirafAdminUser.fromJson(Map<String, dynamic> json) {
    final name =
        '${core.text(json['firstName'])} ${core.text(json['lastName'])}'.trim();
    return OzirafAdminUser(
      id: core.text(json['id']),
      email: core.text(json['email']),
      name: name.isEmpty ? core.text(json['email'], fallback: 'Usuario') : name,
      role: core.text(json['role'], fallback: 'USER'),
      status: core.text(json['status'], fallback: 'ACTIVE'),
      accountType: core.text(json['accountType'], fallback: 'SOLICITANTE'),
      billingStatus: core.text(json['billingStatus'], fallback: 'TRIAL'),
      renewalDueAt: DateTime.tryParse(core.text(json['renewalDueAt'])),
      createdAt: DateTime.tryParse(core.text(json['createdAt'])),
    );
  }
}

class OzirafAdminSummary {
  const OzirafAdminSummary({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.paidUsers,
    required this.dueRenewals,
    required this.overdueRenewals,
    required this.newThisMonth,
    required this.advertisers,
    required this.requesters,
    required this.activePosts,
    required this.openReports,
  });

  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;
  final int paidUsers;
  final int dueRenewals;
  final int overdueRenewals;
  final int newThisMonth;
  final int advertisers;
  final int requesters;
  final int activePosts;
  final int openReports;

  factory OzirafAdminSummary.fromJson(Map<String, dynamic> json) {
    int number(String key) => json[key] is num ? (json[key] as num).toInt() : 0;
    return OzirafAdminSummary(
      totalUsers: number('totalUsers'),
      activeUsers: number('activeUsers'),
      suspendedUsers: number('suspendedUsers'),
      paidUsers: number('paidUsers'),
      dueRenewals: number('dueRenewals'),
      overdueRenewals: number('overdueRenewals'),
      newThisMonth: number('newThisMonth'),
      advertisers: number('advertisers'),
      requesters: number('requesters'),
      activePosts: number('activePosts'),
      openReports: number('openReports'),
    );
  }
}

class OzirafAdminReport {
  const OzirafAdminReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.type,
    required this.postTitle,
    required this.reporter,
    required this.details,
  });

  final String id;
  final String reason;
  final String status;
  final String type;
  final String postTitle;
  final String reporter;
  final String details;

  factory OzirafAdminReport.fromJson(Map<String, dynamic> json) {
    final post = json['post'] is Map<String, dynamic>
        ? json['post'] as Map<String, dynamic>
        : <String, dynamic>{};
    final reporter = json['reporter'] is Map<String, dynamic>
        ? json['reporter'] as Map<String, dynamic>
        : <String, dynamic>{};
    final targetUser = json['targetUser'] is Map<String, dynamic>
        ? json['targetUser'] as Map<String, dynamic>
        : <String, dynamic>{};
    final targetName =
        '${core.text(targetUser['firstName'])} ${core.text(targetUser['lastName'])}'
            .trim();
    final type = core.text(json['type'], fallback: 'POST');
    return OzirafAdminReport(
      id: core.text(json['id']),
      reason: core.text(json['reason'], fallback: 'OTHER'),
      status: core.text(json['status'], fallback: 'OPEN'),
      type: type,
      postTitle: type == 'USER'
          ? targetName.isEmpty
                ? core.text(targetUser['email'], fallback: 'Cuenta reportada')
                : targetName
          : core.text(post['title'], fallback: 'Publicacion reportada'),
      reporter: core.text(reporter['email'], fallback: 'Usuario OZIRAF'),
      details: core.text(json['details']),
    );
  }
}

class OzirafAdminData {
  const OzirafAdminData({
    required this.users,
    required this.posts,
    required this.reports,
    required this.summary,
  });

  final List<OzirafAdminUser> users;
  final List<core.ServicePost> posts;
  final List<OzirafAdminReport> reports;
  final OzirafAdminSummary summary;
}

class OzirafAdminApi {
  OzirafAdminApi._();

  static Future<OzirafAdminData> fetchDashboard(String token) async {
    final results = await Future.wait([
      _request('/users/admin/summary', token),
      _request('/users/admin?page=1&limit=50', token),
      _request('/posts/admin?page=1&limit=50', token),
      _request('/reports/admin?page=1&limit=50', token),
    ]);

    return OzirafAdminData(
      summary: OzirafAdminSummary.fromJson(results[0] as Map<String, dynamic>),
      users: _items(results[1]).map(OzirafAdminUser.fromJson).toList(),
      posts: _items(results[2]).map(core.ServicePost.fromJson).toList(),
      reports: _items(results[3]).map(OzirafAdminReport.fromJson).toList(),
    );
  }

  static Future<OzirafAdminUser> updateUserStatus({
    required String token,
    required String userId,
    required String status,
  }) async {
    final payload = await _request(
      '/users/admin/$userId/status',
      token,
      method: 'PATCH',
      body: {'status': status},
    );
    return OzirafAdminUser.fromJson(payload as Map<String, dynamic>);
  }

  static Future<OzirafAdminUser> updateUserBilling({
    required String token,
    required String userId,
    required String billingStatus,
    DateTime? renewalDueAt,
  }) async {
    final payload = await _request(
      '/users/admin/$userId/billing',
      token,
      method: 'PATCH',
      body: {
        'billingStatus': billingStatus,
        if (renewalDueAt != null)
          'renewalDueAt': renewalDueAt.toIso8601String(),
      },
    );
    return OzirafAdminUser.fromJson(payload as Map<String, dynamic>);
  }

  static Future<core.ServicePost> updatePostStatus({
    required String token,
    required String postId,
    required String status,
  }) async {
    final payload = await _request(
      '/posts/admin/$postId/status',
      token,
      method: 'PATCH',
      body: {'status': status},
    );
    return core.ServicePost.fromJson(payload as Map<String, dynamic>);
  }

  static Future<OzirafAdminReport> updateReportStatus({
    required String token,
    required String reportId,
    required String status,
  }) async {
    final payload = await _request(
      '/reports/admin/$reportId/status',
      token,
      method: 'PATCH',
      body: {'status': status},
    );
    return OzirafAdminReport.fromJson(payload as Map<String, dynamic>);
  }

  static Future<Object?> _request(
    String path,
    String token, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${core.OzirafApiClient.baseUrl}$path');
    final headers = core.authHeaders(token);
    final response = method == 'PATCH'
        ? await http
              .patch(uri, headers: headers, body: jsonEncode(body ?? const {}))
              .timeout(const Duration(seconds: 15))
        : await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
    final payload = core.decodePayload(response.body);
    core.ensureSuccess(response.statusCode, payload);
    return payload;
  }

  static List<Map<String, dynamic>> _items(Object? payload) {
    final raw = payload is Map<String, dynamic> ? payload['data'] : payload;
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }
}

class OzirafAdminDashboard extends StatefulWidget {
  const OzirafAdminDashboard({super.key, required this.token});

  final String token;

  @override
  State<OzirafAdminDashboard> createState() => _OzirafAdminDashboardState();
}

class _OzirafAdminDashboardState extends State<OzirafAdminDashboard> {
  OzirafAdminData? data;
  String section = 'users';
  String? error;
  bool loading = true;

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
      final result = await OzirafAdminApi.fetchDashboard(widget.token);
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  Future<void> updateUser(OzirafAdminUser user, String status) async {
    final updated = await OzirafAdminApi.updateUserStatus(
      token: widget.token,
      userId: user.id,
      status: status,
    );
    setState(() {
      data = OzirafAdminData(
        summary: data!.summary,
        users: data!.users
            .map((item) => item.id == user.id ? updated : item)
            .toList(),
        posts: data!.posts,
        reports: data!.reports,
      );
    });
  }

  Future<void> updatePost(core.ServicePost post, String status) async {
    final updated = await OzirafAdminApi.updatePostStatus(
      token: widget.token,
      postId: post.id,
      status: status,
    );
    setState(() {
      data = OzirafAdminData(
        summary: data!.summary,
        users: data!.users,
        posts: data!.posts
            .map((item) => item.id == post.id ? updated : item)
            .toList(),
        reports: data!.reports,
      );
    });
  }

  Future<void> updateReport(OzirafAdminReport report, String status) async {
    final updated = await OzirafAdminApi.updateReportStatus(
      token: widget.token,
      reportId: report.id,
      status: status,
    );
    setState(() {
      data = OzirafAdminData(
        summary: data!.summary,
        users: data!.users,
        posts: data!.posts,
        reports: data!.reports
            .map((item) => item.id == report.id ? updated : item)
            .toList(),
      );
    });
  }

  Future<void> updateBilling(
    OzirafAdminUser user,
    String billingStatus,
    DateTime? renewalDueAt,
  ) async {
    final updated = await OzirafAdminApi.updateUserBilling(
      token: widget.token,
      userId: user.id,
      billingStatus: billingStatus,
      renewalDueAt: renewalDueAt,
    );
    setState(() {
      data = OzirafAdminData(
        summary: data!.summary,
        users: data!.users
            .map((item) => item.id == user.id ? updated : item)
            .toList(),
        posts: data!.posts,
        reports: data!.reports,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = data;

    return ColoredBox(
      color: const Color(0xFFF7F8FC),
      child: Column(
        children: [
          _AdminHeader(onRefresh: load),
          if (current != null) _AdminSummaryGrid(summary: current.summary),
          _AdminTabs(
            section: section,
            users: current?.users.length ?? 0,
            posts: current?.posts.length ?? 0,
            reports: current?.reports.length ?? 0,
            onChanged: (value) => setState(() => section = value),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? core.ErrorPanel(message: error!, onRetry: load)
                : current == null
                ? const SizedBox.shrink()
                : _AdminSectionBody(
                    data: current,
                    section: section,
                    onUserStatus: updateUser,
                    onUserBilling: updateBilling,
                    onPostStatus: updatePost,
                    onReportStatus: updateReport,
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFF654CFF),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administracion',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Usuarios, publicaciones y reportes',
                  style: TextStyle(color: Color(0xFF697080)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _AdminSummaryGrid extends StatelessWidget {
  const _AdminSummaryGrid({required this.summary});

  final OzirafAdminSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (Icons.group_outlined, 'Usuarios', summary.totalUsers.toString()),
      (Icons.verified_user_outlined, 'Activos', summary.activeUsers.toString()),
      (Icons.block_outlined, 'Suspendidos', summary.suspendedUsers.toString()),
      (Icons.payments_outlined, 'Pagando', summary.paidUsers.toString()),
      (
        Icons.event_repeat_outlined,
        'Por renovar',
        summary.dueRenewals.toString(),
      ),
      (
        Icons.warning_amber_outlined,
        'Vencidos',
        summary.overdueRenewals.toString(),
      ),
      (
        Icons.person_add_alt_outlined,
        'Altas del mes',
        summary.newThisMonth.toString(),
      ),
      (Icons.campaign_outlined, 'Anunciantes', summary.advertisers.toString()),
      (Icons.search_outlined, 'Solicitantes', summary.requesters.toString()),
      (Icons.work_outline, 'Anuncios activos', summary.activePosts.toString()),
      (
        Icons.report_outlined,
        'Reportes abiertos',
        summary.openReports.toString(),
      ),
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 6 : 2,
              childAspectRatio: wide ? 2.25 : 2.45,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final card = cards[index];
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7E9F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(card.$1, color: const Color(0xFF654CFF), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              card.$3,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              card.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF697080),
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
          );
        },
      ),
    );
  }
}

class _AdminTabs extends StatelessWidget {
  const _AdminTabs({
    required this.section,
    required this.users,
    required this.posts,
    required this.reports,
    required this.onChanged,
  });

  final String section;
  final int users;
  final int posts;
  final int reports;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'users', label: Text('Usuarios $users')),
            ButtonSegment(value: 'posts', label: Text('Anuncios $posts')),
            ButtonSegment(value: 'reports', label: Text('Reportes $reports')),
          ],
          selected: {section},
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ),
    );
  }
}

class _AdminSectionBody extends StatelessWidget {
  const _AdminSectionBody({
    required this.data,
    required this.section,
    required this.onUserStatus,
    required this.onUserBilling,
    required this.onPostStatus,
    required this.onReportStatus,
  });

  final OzirafAdminData data;
  final String section;
  final Future<void> Function(OzirafAdminUser user, String status) onUserStatus;
  final Future<void> Function(
    OzirafAdminUser user,
    String billingStatus,
    DateTime? renewalDueAt,
  )
  onUserBilling;
  final Future<void> Function(core.ServicePost post, String status)
  onPostStatus;
  final Future<void> Function(OzirafAdminReport report, String status)
  onReportStatus;

  @override
  Widget build(BuildContext context) {
    if (section == 'posts') {
      return _AdminList(
        empty: 'No hay publicaciones cargadas.',
        children: data.posts
            .map((post) => _PostAdminCard(post: post, onStatus: onPostStatus))
            .toList(),
      );
    }
    if (section == 'reports') {
      return _AdminList(
        empty: 'No hay reportes cargados.',
        children: data.reports
            .map(
              (report) =>
                  _ReportAdminCard(report: report, onStatus: onReportStatus),
            )
            .toList(),
      );
    }
    return _AdminList(
      empty: 'No hay usuarios cargados.',
      children: data.users
          .map(
            (user) => _UserAdminCard(
              user: user,
              onStatus: onUserStatus,
              onBilling: onUserBilling,
            ),
          )
          .toList(),
    );
  }
}

class _AdminList extends StatelessWidget {
  const _AdminList({required this.empty, required this.children});

  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return core.PlaceholderPanel(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Sin datos',
        message: empty,
      );
    }

    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 32 : 14,
        14,
        desktop ? 32 : 14,
        110,
      ),
      children: children,
    );
  }
}

class _UserAdminCard extends StatefulWidget {
  const _UserAdminCard({
    required this.user,
    required this.onStatus,
    required this.onBilling,
  });

  final OzirafAdminUser user;
  final Future<void> Function(OzirafAdminUser user, String status) onStatus;
  final Future<void> Function(
    OzirafAdminUser user,
    String billingStatus,
    DateTime? renewalDueAt,
  )
  onBilling;

  @override
  State<_UserAdminCard> createState() => _UserAdminCardState();
}

class _UserAdminCardState extends State<_UserAdminCard> {
  bool saving = false;

  Future<void> pickRenewal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate:
          widget.user.renewalDueAt ?? now.add(const Duration(days: 30)),
    );
    if (picked == null) return;
    await updateBilling(widget.user.billingStatus, picked);
  }

  Future<void> updateBilling(
    String billingStatus,
    DateTime? renewalDueAt,
  ) async {
    setState(() => saving = true);
    try {
      await widget.onBilling(widget.user, billingStatus, renewalDueAt);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: widget.user.name,
      subtitle:
          '${widget.user.email} - ${_accountLabel(widget.user.accountType)} - Alta ${_dateLabel(widget.user.createdAt)}',
      badge: widget.user.role,
      status: widget.user.status,
      statuses: const ['ACTIVE', 'INACTIVE', 'SUSPENDED'],
      onStatus: (status) => widget.onStatus(widget.user, status),
      footer: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: _billingValues.contains(widget.user.billingStatus)
                ? widget.user.billingStatus
                : 'TRIAL',
            items: _billingValues
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_billingLabel(item)),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (next) {
                    if (next != null) {
                      updateBilling(next, widget.user.renewalDueAt);
                    }
                  },
          ),
          OutlinedButton.icon(
            onPressed: saving ? null : pickRenewal,
            icon: const Icon(Icons.event_repeat_outlined, size: 18),
            label: Text('Renueva ${_dateLabel(widget.user.renewalDueAt)}'),
          ),
          if (saving)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _PostAdminCard extends StatelessWidget {
  const _PostAdminCard({required this.post, required this.onStatus});

  final core.ServicePost post;
  final Future<void> Function(core.ServicePost post, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: post.title,
      subtitle: '${post.providerName} - ${post.city}, ${post.state}',
      badge: post.category,
      status: 'ACTIVE',
      statuses: const ['ACTIVE', 'INACTIVE', 'DELETED'],
      onStatus: (status) => onStatus(post, status),
    );
  }
}

class _ReportAdminCard extends StatelessWidget {
  const _ReportAdminCard({required this.report, required this.onStatus});

  final OzirafAdminReport report;
  final Future<void> Function(OzirafAdminReport report, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return _AdminCard(
      title: report.postTitle,
      subtitle:
          '${report.reporter}${report.details.isEmpty ? '' : ' - ${report.details}'}',
      badge:
          '${report.type == 'USER' ? 'Cuenta' : 'Anuncio'} · ${report.reason}',
      status: report.status,
      statuses: const ['OPEN', 'REVIEWED', 'RESOLVED', 'DISMISSED'],
      onStatus: (status) => onStatus(report, status),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.status,
    required this.statuses,
    required this.onStatus,
    this.footer,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String status;
  final List<String> statuses;
  final ValueChanged<String> onStatus;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final value = statuses.contains(status) ? status : statuses.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(badge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF697080)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: value,
                  items: statuses
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_label(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (next) {
                    if (next != null && next != value) onStatus(next);
                  },
                ),
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 10), footer!],
          ],
        ),
      ),
    );
  }

  static String _label(String value) => switch (value) {
    'ACTIVE' => 'Activo',
    'INACTIVE' => 'Inactivo',
    'SUSPENDED' => 'Suspendido',
    'DELETED' => 'Eliminado',
    'OPEN' => 'Abierto',
    'REVIEWED' => 'Revisado',
    'RESOLVED' => 'Resuelto',
    'DISMISSED' => 'Descartado',
    _ => value,
  };
}

const _billingValues = ['TRIAL', 'PAID', 'DUE', 'OVERDUE', 'EXEMPT'];

String _billingLabel(String value) => switch (value) {
  'TRIAL' => 'Prueba',
  'PAID' => 'Pagando',
  'DUE' => 'Por renovar',
  'OVERDUE' => 'Vencido',
  'EXEMPT' => 'Exento',
  _ => value,
};

String _accountLabel(String value) => switch (value) {
  'ANUNCIANTE' => 'Anunciante',
  'SOLICITANTE' => 'Solicitante',
  _ => value,
};

String _dateLabel(DateTime? value) {
  if (value == null) return 'sin fecha';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';
}
