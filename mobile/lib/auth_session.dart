import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'web_session_storage_stub.dart'
    if (dart.library.html) 'web_session_storage_web.dart'
    as web_storage;

enum OzirafAccountType { solicitante, anunciante }

extension OzirafAccountTypeValue on OzirafAccountType {
  String get apiValue => switch (this) {
    OzirafAccountType.solicitante => 'SOLICITANTE',
    OzirafAccountType.anunciante => 'ANUNCIANTE',
  };

  String get label => switch (this) {
    OzirafAccountType.solicitante => 'Solicitante',
    OzirafAccountType.anunciante => 'Anunciante',
  };
}

OzirafAccountType accountTypeFromValue(Object? value) {
  final normalized = value?.toString().trim().toUpperCase();
  return normalized == 'ANUNCIANTE'
      ? OzirafAccountType.anunciante
      : OzirafAccountType.solicitante;
}

class OzirafProfile {
  const OzirafProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.city,
    required this.state,
    required this.profession,
    required this.phone,
    required this.accountType,
    this.profilePhoto = '',
    this.description = '',
    this.whatsapp = '',
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.tiktokUrl = '',
    this.xUrl = '',
    this.websiteUrl = '',
    this.role = 'USER',
    this.status = 'ACTIVE',
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String city;
  final String state;
  final String profession;
  final String phone;
  final OzirafAccountType accountType;
  final String profilePhoto;
  final String description;
  final String whatsapp;
  final String instagramUrl;
  final String facebookUrl;
  final String tiktokUrl;
  final String xUrl;
  final String websiteUrl;
  final String role;
  final String status;

  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  bool get hasSocialLinks =>
      whatsapp.isNotEmpty ||
      instagramUrl.isNotEmpty ||
      facebookUrl.isNotEmpty ||
      tiktokUrl.isNotEmpty ||
      xUrl.isNotEmpty ||
      websiteUrl.isNotEmpty;

  String get fullName {
    final value = '$firstName $lastName'.trim();
    return value.isEmpty ? email : value;
  }

  String get initials {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty && !part.contains('@'))
        .toList();
    if (parts.isEmpty) {
      return email.isEmpty ? 'O' : email.substring(0, 1).toUpperCase();
    }
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  OzirafProfile copyWith({
    OzirafAccountType? accountType,
    String? firstName,
    String? lastName,
    String? city,
    String? state,
    String? profession,
    String? phone,
    String? profilePhoto,
    String? description,
    String? whatsapp,
    String? instagramUrl,
    String? facebookUrl,
    String? tiktokUrl,
    String? xUrl,
    String? websiteUrl,
    String? role,
    String? status,
  }) {
    final updated = OzirafProfile(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      city: city ?? this.city,
      state: state ?? this.state,
      profession: profession ?? this.profession,
      phone: phone ?? this.phone,
      accountType: accountType ?? this.accountType,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      description: description ?? this.description,
      whatsapp: whatsapp ?? this.whatsapp,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      xUrl: xUrl ?? this.xUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      role: role ?? this.role,
      status: status ?? this.status,
    );
    OzirafSessionStore.profileNotifier.value = updated;
    return updated;
  }

  factory OzirafProfile.fromJson(Map<String, dynamic> json) {
    String text(Object? value) => value is String ? value.trim() : '';

    final profile = OzirafProfile(
      id: text(json['id']),
      email: text(json['email']),
      firstName: text(json['firstName']),
      lastName: text(json['lastName']),
      city: text(json['city']),
      state: text(json['state']),
      profession: text(json['profession']),
      phone: text(json['phone']),
      accountType: accountTypeFromValue(json['accountType']),
      profilePhoto: text(json['profilePhoto']),
      description: text(json['description']),
      whatsapp: text(json['whatsapp']),
      instagramUrl: text(json['instagramUrl']),
      facebookUrl: text(json['facebookUrl']),
      tiktokUrl: text(json['tiktokUrl']),
      xUrl: text(json['xUrl']),
      websiteUrl: text(json['websiteUrl']),
      role: text(json['role']).isEmpty
          ? 'USER'
          : text(json['role']).toUpperCase(),
      status: text(json['status']).isEmpty
          ? 'ACTIVE'
          : text(json['status']).toUpperCase(),
    );
    OzirafSessionStore.profileNotifier.value = profile;
    return profile;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'city': city,
    'state': state,
    'profession': profession,
    'phone': phone,
    'accountType': accountType.apiValue,
    'profilePhoto': profilePhoto,
    'description': description,
    'whatsapp': whatsapp,
    'instagramUrl': instagramUrl,
    'facebookUrl': facebookUrl,
    'tiktokUrl': tiktokUrl,
    'xUrl': xUrl,
    'websiteUrl': websiteUrl,
    'role': role,
    'status': status,
  };
}

class OzirafSessionStore {
  static const _tokenKey = 'oziraf_access_token';
  static const _accountTypeKey = 'oziraf_account_type';
  static const _profileKey = 'oziraf_profile';

  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(
    null,
  );
  static final ValueNotifier<OzirafProfile?> profileNotifier =
      ValueNotifier<OzirafProfile?>(null);

  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(),
  );

  Future<String?> readToken() async {
    final value = kIsWeb
        ? web_storage.readSessionValue(_tokenKey)
        : await _storage.read(key: _tokenKey);
    tokenNotifier.value = value;
    return value;
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      web_storage.writeSessionValue(_tokenKey, token);
      tokenNotifier.value = token;
      return;
    }
    await _storage.write(key: _tokenKey, value: token);
    tokenNotifier.value = token;
  }

  Future<OzirafAccountType?> readAccountType() async {
    final value = kIsWeb
        ? web_storage.readSessionValue(_accountTypeKey)
        : await _storage.read(key: _accountTypeKey);
    if (value == null || value.isEmpty) return null;
    return accountTypeFromValue(value);
  }

  Future<void> saveAccountType(OzirafAccountType type) async {
    if (kIsWeb) {
      web_storage.writeSessionValue(_accountTypeKey, type.apiValue);
      return;
    }
    await _storage.write(key: _accountTypeKey, value: type.apiValue);
  }

  Future<OzirafProfile?> readProfile() async {
    final value = kIsWeb
        ? web_storage.readSessionValue(_profileKey)
        : await _storage.read(key: _profileKey);
    if (value == null || value.trim().isEmpty) return null;
    try {
      final payload = jsonDecode(value);
      if (payload is Map<String, dynamic>) {
        return OzirafProfile.fromJson(payload);
      }
    } catch (_) {
      // Ignore an old or damaged cached profile; the API can refresh it.
    }
    return null;
  }

  Future<void> saveProfile(OzirafProfile profile) async {
    final value = jsonEncode(profile.toJson());
    if (kIsWeb) {
      web_storage.writeSessionValue(_profileKey, value);
      profileNotifier.value = profile;
      return;
    }
    await _storage.write(key: _profileKey, value: value);
    profileNotifier.value = profile;
  }

  Future<void> clear() async {
    if (kIsWeb) {
      web_storage.removeSessionValue(_tokenKey);
      web_storage.removeSessionValue(_accountTypeKey);
      web_storage.removeSessionValue(_profileKey);
      tokenNotifier.value = null;
      profileNotifier.value = null;
      return;
    }
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _accountTypeKey);
    await _storage.delete(key: _profileKey);
    tokenNotifier.value = null;
    profileNotifier.value = null;
  }
}
