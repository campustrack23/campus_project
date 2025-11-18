// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart'; // Import the routes list
import 'theme.dart';
import 'core/providers/theme_provider.dart';

import 'core/services/local_storage.dart';
import 'core/services/notification_service.dart';
import 'core/services/firestore_notifier.dart';
import 'core/services/notification_sync_service.dart';
import 'data/auth_repository.dart';
import 'data/attendance_repository.dart';
import 'data/timetable_repository.dart';
import 'data/query_repository.dart';
import 'data/remark_repository.dart';
import 'data/notification_repository.dart';
// --- FIX: Import new repository ---
import 'data/internal_marks_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/models/user.dart';
import 'core/models/role.dart';

// ===== REPOSITORY PROVIDERS =====
final authRepoProvider = Provider<AuthRepository>((ref) => AuthRepository());
final attendanceRepoProvider = Provider<AttendanceRepository>((ref) => AttendanceRepository());
final timetableRepoProvider = Provider<TimetableRepository>((ref) => TimetableRepository());
final remarkRepoProvider = Provider<RemarkRepository>((ref) => RemarkRepository());
final localStorageProvider = Provider<LocalStorage>((ref) => throw UnimplementedError());

// --- FIX: Add new provider ---
final internalMarksRepoProvider = Provider<InternalMarksRepository>((ref) => InternalMarksRepository());

final notifRepoProvider = Provider<NotificationRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return NotificationRepository(storage);
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firestoreNotifierProvider = Provider<FirestoreNotifier>((ref) => FirestoreNotifier(ref.read(firestoreProvider)));

final queryRepoProvider = Provider<QueryRepository>((ref) {
  return QueryRepository(
    ref.read(notifRepoProvider),
    ref.read(firestoreNotifierProvider),
  );
});

final notifSyncProvider = Provider<NotificationSyncService>((ref) => NotificationSyncService(ref, ref.read(firestoreProvider)));
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());
final notifServiceProvider = Provider<NotificationService>((ref) => NotificationService());

final authStateProvider = StreamProvider<UserAccount?>((ref) {
  return ref.watch(authRepoProvider).authStateChanges();
});

final allUsersProvider = FutureProvider<List<UserAccount>>((ref) async {
  return ref.watch(authRepoProvider).allUsers();
});


// ===== ROUTER PROVIDER =====
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    routes: appRoutes,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.uri.toString();

      return authState.when(
        loading: () => (location == '/') ? null : '/',
        error: (err, stack) => (location == '/login') ? null : '/login',
        data: (user) {
          final bool loggedIn = user != null;
          final bool onLoginPage = location == '/login';
          final bool onSplashPage = location == '/';

          if (!loggedIn) {
            return onLoginPage ? null : '/login';
          }

          if (onLoginPage || onSplashPage) {
            switch (user.role) {
              case UserRole.student:
                return '/home/student';
              case UserRole.teacher:
                return '/home/teacher';
              case UserRole.admin:
                return '/home/admin';
            }
          }
          return null;
        },
      );
    },
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage)
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

    ref.watch(authStateProvider).whenData((user) {
      if (user != null) {
        ref.read(notifSyncProvider).start(user.id);
      } else {
        ref.read(notifSyncProvider).stop();
      }
    });

    return MaterialApp.router(
      title: 'CampusTrack',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}