// lib/core/models/user.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'role.dart';
import '../utils/date_parser.dart';

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
  final String? section; // Kept for backend compatibility, hidden in UI
  final int? year;
  final List<String> qualifications;
  final String? idCardPhotoPath;

  // --- NEW FIELDS ---
  final String? gender; // For both Teacher and Student
  final DateTime? dateOfBirth; // Parsed from "10-03-2008"
  final String? course; // e.g., "BACHELOR OF SCIENCE..."
  final int? semester; // e.g., 2, 4, 6, 8

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
    this.gender,
    this.dateOfBirth,
    this.course,
    this.semester,
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
    String? gender,
    DateTime? dateOfBirth,
    String? course,
    int? semester,
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
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      course: course ?? this.course,
      semester: semester ?? this.semester,
    );
  }

  Map<String, dynamic> toMap() {
    // Convert DateTime back to "DD-MM-YYYY" if it exists
    String? dobStr;
    if (dateOfBirth != null) {
      final d = dateOfBirth!.day.toString().padLeft(2, '0');
      final m = dateOfBirth!.month.toString().padLeft(2, '0');
      final y = dateOfBirth!.year.toString();
      dobStr = '$d-$m-$y';
    }

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
      'gender': gender,
      'date_of_birth': dobStr,
      'course': course,
      'semester': semester,
    };
  }

  factory UserAccount.fromMap(String id, Map<String, dynamic> map) {
    // -------------------------------------------------------------------------
    // SAFE PARSING
    // -------------------------------------------------------------------------

    // 1. Safe Semester & Year Parsing
    int? parsedSemester;
    if (map['semester'] != null) {
      if (map['semester'] is int) {
        parsedSemester = map['semester'];
      } else {
        parsedSemester = int.tryParse(map['semester'].toString());
      }
    }

    int? parsedYear;
    if (map['year'] != null) {
      if (map['year'] is int) {
        parsedYear = map['year'];
      } else {
        parsedYear = int.tryParse(map['year'].toString());
      }
    }

    // Auto-calculate year from semester if year is missing!
    // Sem 1/2 = Year 1, Sem 3/4 = Year 2, Sem 5/6 = Year 3, Sem 7/8 = Year 4
    if (parsedYear == null && parsedSemester != null) {
      parsedYear = (parsedSemester / 2.0).ceil();
    }

    // 2. Safe Date of Birth Parsing ("DD-MM-YYYY" -> DateTime)
    DateTime? dob;
    if (map['date_of_birth'] != null) {
      try {
        final parts = map['date_of_birth'].toString().split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          dob = DateTime(year, month, day);
        }
      } catch (e) {
        debugPrint('Failed to parse date_of_birth: ${map['date_of_birth']}');
      }
    }

    // 3. Safe Bool Parsing
    bool active = true;
    if (map['isActive'] != null) {
      if (map['isActive'] is bool) {
        active = map['isActive'];
      } else {
        active = map['isActive'].toString().toLowerCase() != 'false';
      }
    }

    return UserAccount(
      id: id,
      role: UserRoleX.fromString(map['role']?.toString() ?? ''),
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString() ?? '',
      createdAt: DateParser.parse(map['createdAt'], fieldName: 'UserAccount.createdAt'),
      isActive: active,
      collegeRollNo: map['collegeRollNo']?.toString(),
      examRollNo: map['examRollNo']?.toString(),
      section: map['section']?.toString(),
      year: parsedYear,
      qualifications: (map['qualifications'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      idCardPhotoPath: map['idCardPhotoPath']?.toString(),
      gender: map['gender']?.toString(),
      dateOfBirth: dob,
      course: map['course']?.toString(),
      semester: parsedSemester,
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
        other.gender == gender &&
        other.dateOfBirth == dateOfBirth &&
        other.course == course &&
        other.semester == semester &&
        listEquals(other.qualifications, qualifications);
  }

  @override
  int get hashCode => Object.hash(
    id, role, name, email, phone, isActive, createdAt, collegeRollNo,
    examRollNo, section, year, idCardPhotoPath, gender, dateOfBirth, course, semester, Object.hashAll(qualifications),
  );
}