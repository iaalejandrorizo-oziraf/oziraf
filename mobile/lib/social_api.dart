import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_v2.dart' as core;

class OzirafContactLead {
  const OzirafContactLead({
    required this.id,
    required this.message,
    required this.status,
    required this.post,
    required this.personName,
    required this.createdAt,
  });

  final String id;
  final String message;
  final String status;
  final core.ServicePost post;
  final String personName;
  final DateTime? createdAt;

  factory OzirafContactLead.fromJson(
    Map<String, dynamic> json, {
    required bool received,
  }) {
    final postJson = json['post'] is Map<String, dynamic>
        ? json['post'] as Map<String, dynamic>
        : <String, dynamic>{};
    final personKey = received ? 'sender' : 'owner';
    final person = json[personKey] is Map<String, dynamic>
        ? json[personKey] as Map<String, dynamic>
        : <String, dynamic>{};
    final firstName = _text(person['firstName']);
    final lastName = _text(person['lastName']);
    final personName = '$firstName $lastName'.trim();

    return OzirafContactLead(
      id: _text(json['id']),
      message: _text(json['message']),
      status: _text(json['status'], fallback: 'NEW'),
      post: core.ServicePost.fromJson(postJson),
      personName: personName.isEmpty ? 'Usuario OZIRAF' : personName,
      createdAt: DateTime.tryParse(_text(json['createdAt'])),
    );
  }
}

class OzirafReview {
  const OzirafReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.authorName,
  });

  final String id;
  final int rating;
  final String comment;
  final String authorName;

  factory OzirafReview.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map<String, dynamic>
        ? json['author'] as Map<String, dynamic>
        : <String, dynamic>{};
    final firstName = _text(author['firstName']);
    final lastName = _text(author['lastName']);
    final authorName = '$firstName $lastName'.trim();
    final ratingValue = json['rating'];

    return OzirafReview(
      id: _text(json['id']),
      rating: ratingValue is num ? ratingValue.toInt().clamp(1, 5) : 5,
      comment: _text(json['comment']),
      authorName: authorName.isEmpty ? 'Usuario OZIRAF' : authorName,
    );
  }
}

class OzirafSocialApi {
  OzirafSocialApi._();

  static Future<List<core.ServicePost>> fetchFavorites(String token) async {
    final payload = await _request(
      'GET',
      '/favorites?page=1&limit=50',
      token: token,
    );
    return _items(payload)
        .map((item) => item['post'])
        .whereType<Map<String, dynamic>>()
        .map(core.ServicePost.fromJson)
        .where((post) => post.id.isNotEmpty)
        .toList();
  }

  static Future<void> saveFavorite(String token, String postId) async {
    await _request('POST', '/favorites/$postId', token: token);
  }

  static Future<void> removeFavorite(String token, String postId) async {
    await _request('DELETE', '/favorites/$postId', token: token);
  }

  static Future<void> sendContact({
    required String token,
    required String postId,
    required String message,
  }) async {
    await _request(
      'POST',
      '/contacts/posts/$postId',
      token: token,
      body: {'message': message.trim()},
    );
  }

  static Future<List<OzirafContactLead>> fetchReceived(String token) async {
    final payload = await _request(
      'GET',
      '/contacts/leads?page=1&limit=50',
      token: token,
    );
    return _items(payload)
        .map((item) => OzirafContactLead.fromJson(item, received: true))
        .toList();
  }

  static Future<List<OzirafContactLead>> fetchSent(String token) async {
    final payload = await _request(
      'GET',
      '/contacts/sent?page=1&limit=50',
      token: token,
    );
    return _items(payload)
        .map((item) => OzirafContactLead.fromJson(item, received: false))
        .toList();
  }

  static Future<void> updateContactStatus({
    required String token,
    required String leadId,
    required String status,
  }) async {
    await _request(
      'PATCH',
      '/contacts/leads/$leadId/status',
      token: token,
      body: {'status': status},
    );
  }

  static Future<List<OzirafReview>> fetchReviews(String postId) async {
    final payload = await _request(
      'GET',
      '/reviews/posts/$postId?page=1&limit=50',
    );
    return _items(payload).map(OzirafReview.fromJson).toList();
  }

  static Future<OzirafReview> createReview({
    required String token,
    required String postId,
    required int rating,
    required String comment,
  }) async {
    final payload = await _request(
      'POST',
      '/reviews/posts/$postId',
      token: token,
      body: {
        'rating': rating.clamp(1, 5),
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
    );
    if (payload is Map<String, dynamic>) {
      return OzirafReview.fromJson(payload);
    }
    throw Exception('El servidor no devolvió la opinión publicada.');
  }

  static Future<void> reportPost({
    required String token,
    required String postId,
    required String reason,
    String details = '',
  }) async {
    await _request(
      'POST',
      '/reports/posts/$postId',
      token: token,
      body: {
        'reason': reason,
        if (details.trim().isNotEmpty) 'details': details.trim(),
      },
    );
  }

  static Future<Object?> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${core.OzirafApiClient.baseUrl}$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': 'Bearer ${token.trim()}',
    };
    late final http.Response response;

    switch (method) {
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(const Duration(seconds: 15));
      case 'PATCH':
        response = await http
            .patch(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(const Duration(seconds: 15));
      case 'DELETE':
        response = await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      default:
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
    }

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

String _text(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}
