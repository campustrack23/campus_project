// lib/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Common
import 'features/about/about_page.dart';
import 'features/auth/splash_page.dart';
import 'features/auth/login_page.dart';
import 'features/profile/my_profile_page.dart';
import 'features/profile/update_profile_page.dart';
import 'features/notifications/notification_page.dart';
import 'features/notices/notices_page.dart';
import 'features/assignments/assignments_page.dart';
import 'features/people/students_directory_page.dart';
import 'features/people/teacher_directory_page.dart';

// Student
import 'features/student/student_home_page.dart';
import 'features/student/student_attendance_page.dart';
import 'features/student/timetable_page.dart';
import 'features/student/raise_query_page.dart';
import 'features/student/scan_qr_page.dart';
import 'features/student/internal_marks_page.dart' as student_marks;

// Teacher
import 'features/teacher/teacher_home_page.dart';
import 'features/teacher/generate_qr_page.dart';
import 'features/teacher/review_attendance_page.dart';
import 'features/teacher/remarks_board_page.dart';
import 'features/teacher/internal_marks_page.dart' as teacher_marks;

// Admin
import 'features/admin/admin_home_page.dart';
import 'features/admin/user_management_page.dart';
import 'features/admin/timetable_builder_page.dart';
import 'features/admin/attendance_overrides_page.dart';
import 'features/admin/internal_marks_overrides_page.dart';
import 'features/admin/import_export_page.dart';
import 'features/admin/reset_passwords_page.dart';
import 'features/admin/query_management_page.dart';

import 'core/models/role.dart';
import 'main.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  // Map route prefixes to required roles for explicit security checking
  final Map<String, List<UserRole>> routePermissions = {
    '/admin': [UserRole.admin],
    '/teacher': [UserRole.teacher],
    '/student': [UserRole.student],
    // SECURITY FIX: Explicitly block students from viewing the directory
    '/students/directory': [UserRole.admin, UserRole.teacher],
  };

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final user = authState.valueOrNull;

      if (isLoading) return '/'; // Force splash while loading

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/';

      if (user == null) {
        if (!isGoingToLogin) return '/login';
        return null;
      }

      if (isGoingToLogin || isGoingToSplash) {
        return '/home/${user.role.key}';
      }

      // 🔴 BUG FIX: Sort prefixes by length (longest first).
      // This prevents '/students/directory' from accidentally triggering the '/student' ban!
      final prefixes = routePermissions.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      for (final prefix in prefixes) {
        if (state.matchedLocation.startsWith(prefix)) {
          final allowedRoles = routePermissions[prefix]!;
          if (!allowedRoles.contains(user.role)) {
            // Kick them back to their home screen if they try to access a blocked route
            return '/home/${user.role.key}';
          }
          // Stop checking once we find the exact matching path
          break;
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

      // ===== COMMON =====
      GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
      GoRoute(path: '/profile', builder: (_, __) => const MyProfilePage()),
      GoRoute(path: '/profile/update', builder: (_, __) => const UpdateProfilePage()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      GoRoute(path: '/notices', builder: (_, __) => const NoticesPage()),
      GoRoute(path: '/assignments', builder: (_, __) => const AssignmentsPage()),
      GoRoute(path: '/teachers/directory', builder: (_, __) => const TeacherDirectoryPage()),

      // ===== RESTRICTED COMMON =====
      GoRoute(path: '/students/directory', builder: (_, __) => const StudentsDirectoryPage()),

      // ===== STUDENT =====
      GoRoute(path: '/home/student', builder: (_, __) => const StudentHomePage()),
      GoRoute(path: '/student/attendance', builder: (_, __) => const StudentAttendancePage()),
      GoRoute(path: '/student/timetable', builder: (_, __) => const TimetablePage()),
      GoRoute(path: '/student/raise-query', builder: (_, __) => const RaiseQueryPage()),
      GoRoute(path: '/student/internal-marks', builder: (_, __) => const student_marks.InternalMarksPage()),
      GoRoute(path: '/student/scan-qr', builder: (_, __) => const ScanQRPage()),

      // ===== TEACHER =====
      GoRoute(path: '/home/teacher', builder: (_, __) => const TeacherHomePage()),
      GoRoute(
        path: '/teacher/generate-qr/:entryId',
        builder: (ctx, state) {
          final entryId = state.pathParameters['entryId'] ?? '';
          return GenerateQRPage(entryId: entryId);
        },
      ),
      GoRoute(
        path: '/teacher/review-attendance/:sessionId',
        builder: (ctx, state) {
          final sessionId = state.pathParameters['sessionId'] ?? '';
          return ReviewAttendancePage(sessionId: sessionId);
        },
      ),
      GoRoute(path: '/teacher/remarks-board', builder: (_, __) => const RemarksBoardPage()),
      GoRoute(path: '/teacher/internal-marks', builder: (_, __) => const teacher_marks.InternalMarksPage()),

      // ===== ADMIN =====
      GoRoute(path: '/home/admin', builder: (_, __) => const AdminHomePage()),
      GoRoute(
        path: '/admin/users',
        builder: (ctx, state) {
          final addStudent = state.uri.queryParameters['add'] == 'student';
          return UserManagementPage(addStudentOnOpen: addStudent);
        },
      ),
      GoRoute(path: '/admin/timetable', builder: (_, __) => const TimetableBuilderPage()),
      GoRoute(path: '/admin/attendance-overrides', builder: (_, __) => const AttendanceOverridesPage()),
      GoRoute(path: '/admin/internal-marks-overrides', builder: (_, __) => const InternalMarksOverridesPage()),
      GoRoute(path: '/admin/import-export', builder: (_, __) => const ImportExportPage()),
      GoRoute(path: '/admin/reset-passwords', builder: (_, __) => const ResetPasswordsPage()),
      GoRoute(path: '/admin/query-management', builder: (_, __) => const QueryManagementPage()),
    ],
  );
});