// lib/core/models/user.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For listEquals
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
  final List<String> qualifications; // Teacher specific

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
    this.qualifications = const [],
  });

  // Helper to check if data is incomplete (e.g. "Complete Profile" screens)
  bool get isProfileComplete {
    if (role == UserRole.student) {
      return collegeRollNo != null && examRollNo != null && section != null;
    }
    return true;
  }

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
    List<String>? qualifications,
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
        createdAt: createdAt, // Usually doesn't change
        qualifications: qualifications ?? this.qualifications,
      );

  Map<String, dynamic> toMap() => {
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
    'createdAt': Timestamp.fromDate(createdAt),
    'qualifications': qualifications,
  };

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is String) return DateTime.tryParse(input) ?? DateTime.now();
      if (input is DateTime) return input;
      return DateTime.now();
    }

    return UserAccount(
      id: map['id'] ?? '',
      role: UserRoleX.fromKey(map['role']),
      name: map['name'] ?? 'Unknown User',
      email: map['email'],
      phone: map['phone'] ?? '',
      collegeRollNo: map['collegeRollNo'],
      examRollNo: map['examRollNo'],
      idCardPhotoPath: map['idCardPhotoPath'],
      section: map['section'],
      year: (map['year'] as num?)?.toInt(),
      passwordHash: map['passwordHash'] ?? '',
      isActive: (map['isActive'] as bool?) ?? true,
      createdAt: parseDate(map['createdAt']),
      qualifications: (map['qualifications'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }

  static String hashPassword(String raw) {
    final bytes = utf8.encode(raw);
    return sha256.convert(bytes).toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAccount &&
        other.id == id &&
        other.role == role &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.collegeRollNo == collegeRollNo &&
        other.examRollNo == examRollNo &&
        other.idCardPhotoPath == idCardPhotoPath &&
        other.section == section &&
        other.year == year &&
        other.passwordHash == passwordHash &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        listEquals(other.qualifications, qualifications);
  }

  @override
  int get hashCode {
    return id.hashCode ^
    role.hashCode ^
    name.hashCode ^
    (email?.hashCode ?? 0) ^
    phone.hashCode ^
    (collegeRollNo?.hashCode ?? 0) ^
    (examRollNo?.hashCode ?? 0) ^
    (idCardPhotoPath?.hashCode ?? 0) ^
    (section?.hashCode ?? 0) ^
    (year?.hashCode ?? 0) ^
    passwordHash.hashCode ^
    isActive.hashCode ^
    createdAt.hashCode ^
    Object.hashAll(qualifications);
  }
}
