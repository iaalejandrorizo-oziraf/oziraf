import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  }) {
    return OzirafProfile(
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
    );
  }

  factory OzirafProfile.fromJson(Map<String, dynamic> json) {
    String text(Object? value) => value is String ? value.trim() : '';

    return OzirafProfile(
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
    );
  }
}

class OzirafSessionStore {
  static const _tokenKey = 'oziraf_access_token';
  static const _accountTypeKey = 'oziraf_account_type';

  static final ValueNotifier<String?> tokenNotifier = ValueNotifier<String?>(null);

  // The local development web app is served over HTTP. Secure web storage
  // requires HTTPS, so web sessions intentionally remain in memory only.
  static String? _webToken;
  static String? _webAccountType;

  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(),
  );

  Future<String?> readToken() async {
    final value = kIsWeb ? _webToken : await _storage.read(key: _tokenKey);
    tokenNotifier.value = value;
    return value;
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      _webToken = token;
      tokenNotifier.value = token;
      return;
    }
    await _storage.write(key: _tokenKey, value: token);
    tokenNotifier.value = token;
  }

  Future<OzirafAccountType?> readAccountType() async {
    final value = kIsWeb
        ? _webAccountType
        : await _storage.read(key: _accountTypeKey);
    if (value == null || value.isEmpty) return null;
    return accountTypeFromValue(value);
  }

  Future<void> saveAccountType(OzirafAccountType type) async {
    if (kIsWeb) {
      _webAccountType = type.apiValue;
      return;
    }
    await _storage.write(key: _accountTypeKey, value: type.apiValue);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      _webToken = null;
      _webAccountType = null;
      tokenNotifier.value = null;
      return;
    }
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _accountTypeKey);
    tokenNotifier.value = null;
  }
}
