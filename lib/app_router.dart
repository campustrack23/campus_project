// lib/app_router.dart
import 'package:go_router/go_router.dart';

// Common
import 'features/about/about_page.dart';
import 'features/auth/splash_page.dart';
import 'features/auth/login_page.dart';
import 'features/profile/my_profile_page.dart';
import 'features/notifications/notification_page.dart';
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

/// Defines all the routes in the app.
final appRoutes = <RouteBase>[
  // ===== AUTH =====
  GoRoute(path: '/', builder: (_, __) => const SplashPage()),
  GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

  // ===== COMMON =====
  GoRoute(path: '/profile', builder: (_, __) => const MyProfilePage()),
  GoRoute(path: '/about', builder: (_, __) => const AboutPage()),
  GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
  GoRoute(path: '/students/directory', builder: (_, __) => const StudentsDirectoryPage()),
  GoRoute(path: '/teachers/directory', builder: (_, __) => const TeacherDirectoryPage()),

  // ===== HOME =====
  GoRoute(path: '/home/student', builder: (_, __) => const StudentHomePage()),
  GoRoute(path: '/home/teacher', builder: (_, __) => const TeacherHomePage()),
  GoRoute(path: '/home/admin', builder: (_, __) => const AdminHomePage()),

  // ===== STUDENT =====
  GoRoute(path: '/student/attendance', builder: (_, __) => const StudentAttendancePage()),
  GoRoute(path: '/student/internal-marks', builder: (_, __) => const student_marks.InternalMarksPage()),
  GoRoute(path: '/student/timetable', builder: (_, __) => const TimetablePage()),
  GoRoute(path: '/student/raise-query', builder: (_, __) => const RaiseQueryPage()),
  GoRoute(path: '/student/scan-qr', builder: (_, __) => const ScanQRPage()),

  // ===== TEACHER =====
  GoRoute(
    path: '/teacher/mark/:entryId',
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
  GoRoute(path: '/admin/queries', builder: (_, __) => const QueryManagementPage()),
];