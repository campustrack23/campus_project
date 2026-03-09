// lib/core/models/user.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'role.dart';

class UserAccount {
  final String id;
  final UserRole role;
  final String name;
  final String? email;
  final String phone;
  final DateTime createdAt;
  final bool isActive;
  final String? collegeRollNo;
  final String? examRollNo;
  final String? section;
  final int? year;
  final List<String> qualifications;
  final String? idCardPhotoPath;

  const UserAccount({
    required this.id,
    required this.role,
    required this.name,
    this.email,
    required this.phone,
    required this.createdAt,
    this.isActive = true,
    this.collegeRollNo,
    this.examRollNo,
    this.section,
    this.year,
    this.qualifications = const [],
    this.idCardPhotoPath,
  });

  UserAccount copyWith({
    String? id,
    UserRole? role,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    bool? isActive,
    String? collegeRollNo,
    String? examRollNo,
    String? section,
    int? year,
    List<String>? qualifications,
    String? idCardPhotoPath,
  }) {
    return UserAccount(
      id: id ?? this.id,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      collegeRollNo: collegeRollNo ?? this.collegeRollNo,
      examRollNo: examRollNo ?? this.examRollNo,
      section: section ?? this.section,
      year: year ?? this.year,
      qualifications: qualifications ?? this.qualifications,
      idCardPhotoPath: idCardPhotoPath ?? this.idCardPhotoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role.key,
      'name': name,
      'email': email,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'collegeRollNo': collegeRollNo,
      'examRollNo': examRollNo,
      'section': section,
      'year': year,
      'qualifications': qualifications,
      'idCardPhotoPath': idCardPhotoPath,
    };
  }

  factory UserAccount.fromMap(String id, Map<String, dynamic> map) {
    // SECURITY FIX: Strict parsing. Do not mask corrupted data with DateTime.now()
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);
      if (input is String) return DateTime.parse(input);
      throw FormatException('Invalid or missing date format in UserAccount: $input');
    }

    return UserAccount(
      id: id,
      role: UserRoleX.fromString(map['role']),
      name: map['name'] ?? '',
      email: map['email'],
      phone: map['phone'] ?? '',
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] ?? true,
      collegeRollNo: map['collegeRollNo'],
      examRollNo: map['examRollNo'],
      section: map['section'],
      year: map['year'],
      qualifications: (map['qualifications'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
      idCardPhotoPath: map['idCardPhotoPath'],
    );
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
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.collegeRollNo == collegeRollNo &&
        other.examRollNo == examRollNo &&
        other.section == section &&
        other.year == year &&
        other.idCardPhotoPath == idCardPhotoPath &&
        listEquals(other.qualifications, qualifications);
  }

  @override
  int get hashCode => Object.hash(
    id,
    role,
    name,
    email,
    phone,
    isActive,
    createdAt,
    collegeRollNo,
    examRollNo,
    section,
    year,
    idCardPhotoPath,
    Object.hashAll(qualifications),
  );
}