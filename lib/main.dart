// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'theme.dart';

import 'core/models/role.dart';
import 'core/models/user.dart';
import 'core/services/local_storage.dart';
import 'core/providers/theme_provider.dart';
import 'app_router.dart';

// --- Repositories ---
import 'data/auth_repository.dart';
import 'data/attendance_repository.dart';
import 'data/timetable_repository.dart';
import 'data/internal_marks_repository.dart';
import 'data/remark_repository.dart';
import 'data/query_repository.dart';
import 'data/notification_repository.dart';

// --- Services ---
import 'core/services/notification_service.dart';
import 'core/services/firestore_notifier.dart';
import 'core/services/notification_sync_service.dart';

// -----------------------------------------------------------------------------
// GLOBAL PROVIDERS (Central Registry)
// -----------------------------------------------------------------------------

final notifServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notifServiceProvider must be overridden in main.dart');
});

final authRepoProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AuthRepository(storage);
});

final attendanceRepoProvider = Provider<AttendanceRepository>((ref) => AttendanceRepository());
final timetableRepoProvider = Provider<TimetableRepository>((ref) => TimetableRepository());
final internalMarksRepoProvider = Provider<InternalMarksRepository>((ref) => InternalMarksRepository());

final firestoreNotifierProvider = Provider<FirestoreNotifier>((ref) {
  final local = ref.watch(notifServiceProvider);
  return FirestoreNotifier(localService: local);
});

final remarkRepoProvider = Provider<RemarkRepository>((ref) {
  final notifier = ref.watch(firestoreNotifierProvider);
  return RemarkRepository(notifier);
});

final queryRepoProvider = Provider<QueryRepository>((ref) {
  final notifier = ref.watch(firestoreNotifierProvider);
  return QueryRepository(notifier);
});

final notifRepoProvider = Provider<NotificationRepository>((ref) => NotificationRepository());

final notificationSyncServiceProvider = Provider<NotificationSyncService>((ref) {
  return NotificationSyncService(ref, FirebaseFirestore.instance);
});

// -----------------------------------------------------------------------------
// AUTH STATE
// -----------------------------------------------------------------------------

final authStateProvider = StreamProvider<UserAccount?>((ref) {
  final repo = ref.watch(authRepoProvider);
  return repo.authStateChanges();
});

// -----------------------------------------------------------------------------
// ROUTER STATE SYNCHRONIZATION
// -----------------------------------------------------------------------------

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<UserAccount?>>(
      authStateProvider,
          (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

// -----------------------------------------------------------------------------
// ROUTER (WITH FIXED ROLE-BASED GUARDS)
// -----------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      // 1. Prevent premature redirection during load phase
      if (authState.isLoading || authState.hasError) {
        return null; // Stay on Splash
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final path = state.uri.path;
      final isLoggingIn = path == '/login';
      final isSplash = path == '/';

      // 2. Not Logged In -> Force Login
      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // Helper function to get the correct home route for a user
      String getHomeRoute() {
        switch (user.role) {
          case UserRole.student:
            return '/home/student';
          case UserRole.teacher:
            return '/home/teacher';
          case UserRole.admin:
            return '/home/admin';
        }
      }

      // 3. Logged In -> Redirect away from Login or Splash
      if (isLoggingIn || isSplash) {
        return getHomeRoute();
      }

      // -----------------------------------------------------------------------
      // 🚨 SECURITY FIX: ROLE-BASED URL GUARDS
      // Added trailing slashes (e.g., '/admin/') so it doesn't accidentally
      // block shared routes like '/students/directory' or '/teachers/directory'
      // -----------------------------------------------------------------------

      // If a non-admin tries to access /admin/ or /home/admin
      if (path.startsWith('/admin/') || path == '/home/admin') {
        if (user.role != UserRole.admin) return getHomeRoute();
      }

      // If a non-teacher tries to access /teacher/ or /home/teacher
      if (path.startsWith('/teacher/') || path == '/home/teacher') {
        if (user.role != UserRole.teacher) return getHomeRoute();
      }

      // If a non-student tries to access /student/ or /home/student
      if (path.startsWith('/student/') || path == '/home/student') {
        if (user.role != UserRole.student) return getHomeRoute();
      }

      // 4. Default: Allow navigation for shared routes (/profile, /notifications, /teachers/directory, etc.)
      return null;
    },
    routes: appRoutes,
  );
});

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);

  final notifService = NotificationService();
  await notifService.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(localStorage),
        notifServiceProvider.overrideWithValue(notifService),
      ],
      child: const CampusTrackApp(),
    ),
  );
}

class CampusTrackApp extends ConsumerStatefulWidget {
  const CampusTrackApp({super.key});

  @override
  ConsumerState<CampusTrackApp> createState() => _CampusTrackAppState();
}

class _CampusTrackAppState extends ConsumerState<CampusTrackApp> {
  late NotificationSyncService _notifSync;

  @override
  void initState() {
    super.initState();
    _notifSync = ref.read(notificationSyncServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    ref.listen<AsyncValue<UserAccount?>>(authStateProvider, (prev, next) {
      next.whenData((user) {
        if (user != null) {
          _notifSync.start(user.id);
        } else {
          _notifSync.stop();
        }
      });
    });

    return MaterialApp.router(
      title: 'Campus Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}