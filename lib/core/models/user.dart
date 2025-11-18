// lib/core/models/user.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'role.dart';

class UserAccount {
  final String id;
  final UserRole role;
  final String name;
  final String? email;
  final String phone;
  final String? collegeRollNo;   // 63xxx
  final String? examRollNo;      // 220xxxxxxxx
  final String? idCardPhotoPath;
  final String? section;         // e.g., "IV-HE"
  final int? year;               // 1..4 for students
  final String passwordHash;
  final bool isActive;
  final DateTime createdAt;

  // --- NEW FIELD ---
  final List<String> qualifications;

  const UserAccount({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    required this.phone,
    this.collegeRollNo,
    this.examRollNo,
    this.idCardPhotoPath,
    this.section,
    this.year,
    required this.passwordHash,
    this.isActive = true,
    required this.createdAt,
    this.qualifications = const [], // Default to empty list
  });

  UserAccount copyWith({
    String? name,
    String? email,
    String? phone,
    String? collegeRollNo,
    String? examRollNo,
    String? idCardPhotoPath,
    String? section,
    int? year,
    String? passwordHash,
    bool? isActive,
    List<String>? qualifications, // Add to copyWith
  }) =>
      UserAccount(
        id: id,
        role: role,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        collegeRollNo: collegeRollNo ?? this.collegeRollNo,
        examRollNo: examRollNo ?? this.examRollNo,
        idCardPhotoPath: idCardPhotoPath ?? this.idCardPhotoPath,
        section: section ?? this.section,
        year: year ?? this.year,
        passwordHash: passwordHash ?? this.passwordHash,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        qualifications: qualifications ?? this.qualifications, // Add to copyWith
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'role': role.key,
    'name': name,
    'email': email,
    'phone': phone,
    'collegeRollNo': collegeRollNo,
    'examRollNo': examRollNo,
    'idCardPhotoPath': idCardPhotoPath,
    'section': section,
    'year': year,
    'passwordHash': passwordHash,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'qualifications': qualifications, // Add to toMap
  };

  factory UserAccount.fromMap(Map<String, dynamic> map) => UserAccount(
    id: map['id'] as String,
    role: UserRoleX.fromKey(map['role'] as String),
    name: map['name'] as String,
    email: map['email'] as String?,
    phone: map['phone'] as String,
    collegeRollNo: map['collegeRollNo'] as String?,
    examRollNo: map['examRollNo'] as String?,
    idCardPhotoPath: map['idCardPhotoPath'] as String?,
    section: map['section'] as String?,
    year: (map['year'] as num?)?.toInt(),
    passwordHash: map['passwordHash'] as String,
    isActive: (map['isActive'] as bool?) ?? true,
    createdAt: DateTime.parse(map['createdAt'] as String),
    // Read from map, default to empty list if null
    qualifications: (map['qualifications'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList() ?? const [],
  );

  static String hashPassword(String raw) {
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString();
  }
}