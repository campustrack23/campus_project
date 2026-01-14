// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'app_router.dart';
import 'theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/models/user.dart';
import 'core/models/role.dart';
import 'core/services/local_storage.dart';
import 'core/services/notification_service.dart';
import 'core/services/firestore_notifier.dart';
import 'core/services/notification_sync_service.dart';
import 'data/auth_repository.dart';
import 'data/attendance_repository.dart';
import 'data/timetable_repository.dart';
import 'data/query_repository.dart';
import 'data/remark_repository.dart';
import 'data/internal_marks_repository.dart';

// ===== 1. CORE SERVICES =====

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  return db;
});

final firestoreNotifierProvider = Provider<FirestoreNotifier>((ref) {
  return FirestoreNotifier(ref.watch(firestoreProvider));
});

// ===== 2. REPOSITORIES =====

final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(localStorageProvider));
});

final attendanceRepoProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

final timetableRepoProvider = Provider<TimetableRepository>((ref) {
  return TimetableRepository();
});

final remarkRepoProvider = Provider<RemarkRepository>((ref) {
  return RemarkRepository(ref.read(firestoreNotifierProvider));
});

final internalMarksRepoProvider = Provider<InternalMarksRepository>((ref) {
  return InternalMarksRepository();
});

final queryRepoProvider = Provider<QueryRepository>((ref) {
  return QueryRepository(ref.read(firestoreNotifierProvider));
});

// ===== 3. LOGIC PROVIDERS =====

final notifSyncProvider = Provider<NotificationSyncService>((ref) {
  return NotificationSyncService(ref, ref.watch(firestoreProvider));
});

final authStateProvider = StreamProvider<UserAccount?>((ref) {
  return ref.watch(authRepoProvider).authStateChanges();
});

final allUsersProvider = FutureProvider<List<UserAccount>>((ref) async {
  return ref.watch(authRepoProvider).allUsers();
});

// ===== 4. ROUTER (SECURE) =====

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authRepo = ref.watch(authRepoProvider);

  return GoRouter(
    routes: appRoutes,
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges()),
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.uri.toString();
      final user = authState.valueOrNull;
      final isLoading = authState.isLoading;
      final hasError = authState.hasError;

      // 1. Loading & Error States
      if (isLoading) return (location == '/') ? null : '/';
      if (hasError) return '/login';

      // 2. Auth Checks
      final loggedIn = user != null;
      final onLoginPage = location == '/login';
      final onSplashPage = location == '/';

      // If not logged in, force login (unless already there)
      if (!loggedIn) return onLoginPage ? null : '/login';

      // 3. Redirect Logged-in Users away from Auth pages
      if (onLoginPage || onSplashPage) {
        switch (user.role) {
          case UserRole.student: return '/home/student';
          case UserRole.teacher: return '/home/teacher';
          case UserRole.admin: return '/home/admin';
        }
      }

      // 4. SECURITY: Role-Based Access Control (RBAC)
      // Prevent Students/Teachers from accessing Admin routes
      if (location.startsWith('/admin')) {
        if (user.role != UserRole.admin) {
          return '/home/${user.role.name}'; // Kick back to their dashboard
        }
      }

      // Prevent Students from accessing Teacher routes
      if (location.startsWith('/teacher')) {
        if (user.role != UserRole.teacher && user.role != UserRole.admin) {
          return '/home/${user.role.name}';
        }
      }

      // Prevent Teachers/Admins from accessing Student routes (Optional, but cleaner)
      if (location.startsWith('/student')) {
        if (user.role != UserRole.student && user.role != UserRole.admin) {
          // Admins might want to debug student views, so maybe allow them,
          // but for strictness:
          return '/home/${user.role.name}';
        }
      }

      return null; // Allow access
    },
  );
});

// ===== MAIN APP =====

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  final notifService = NotificationService();
  await notifService.init();
  await notifService.requestPermissions();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        notifServiceProvider.overrideWithValue(notifService),
      ],
      child: const CampusTrackApp(),
    ),
  );
}

class CampusTrackApp extends ConsumerWidget {
  const CampusTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(goRouterProvider);

    ref.listen<AsyncValue<UserAccount?>>(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          ref.read(notifSyncProvider).start(user.id);
        } else {
          ref.read(notifSyncProvider).stop();
        }
      });
    });

    return MaterialApp.router(
      title: 'CampusTrack',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}